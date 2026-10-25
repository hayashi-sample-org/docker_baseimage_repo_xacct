#!/usr/bin/env bash
# =============================================================================
# マルチアーキの子manifest（amd64 / arm64 の本体）に個別署名するスクリプト
#
# 背景:
#   docker buildx build --push で作られる image index（目次）に notation sign
#   しても、その署名は index にしか付かず、子manifest（各アーキの本体）には
#   伝播しない。そこで index 署名とは別に、子それぞれにも個別署名する。
#
# このスクリプトがやること:
#   1. imagetools inspect で image index の中身(JSON)を取得
#   2. jq で実アーキ（linux/amd64・linux/arm64）の子digestだけを抜き出す
#      （attestation の unknown/unknown は platform.architecture が "unknown"
#        なので、この絞り込みで自然に除外される）
#   3. 取り出した各digestに notation sign を実行
#
# 必要な環境変数（buildspec 側から渡す）:
#   ECR_URI               例) <acct>.dkr.ecr.<region>.amazonaws.com/<repo>
#   ECR_IMAGE             例) ${ECR_URI}:<tag>（タグ付きの完全な参照）
#   SIGNING_PROFILE_ARN   AWS Signer の署名プロファイル ARN
#   NOTATION_USERNAME     ECR 認証ユーザー（AWS）
#   NOTATION_PASSWORD     ECR 認証パスワード（get-login-password の値）
#
# 注意:
#   buildspec の commands に直書きすると jq のコロン・クォートで YAML パース
#   エラーを踏みやすいため、処理をこのスクリプトに隔離している。
# =============================================================================

set -euo pipefail

echo "===== 子manifest個別署名 開始 ====="

# 必須環境変数のチェック（未設定なら早期に失敗させる）
: "${ECR_URI:?ECR_URI is required}"
: "${ECR_IMAGE:?ECR_IMAGE is required}"
: "${SIGNING_PROFILE_ARN:?SIGNING_PROFILE_ARN is required}"

# image index の中身を JSON で取得し、linux/amd64・linux/arm64 の子digestを抽出
# （unknown/unknown の attestation は architecture!=amd64/arm64 なので除外される）
CHILD_DIGESTS=$(docker buildx imagetools inspect "${ECR_IMAGE}" --format '{{json .Manifest}}' \
  | jq -r '.manifests[]
           | select(.platform.os == "linux")
           | select(.platform.architecture == "amd64" or .platform.architecture == "arm64")
           | .digest')

if [ -z "${CHILD_DIGESTS}" ]; then
  echo "ERROR: 子manifestのdigestが取得できませんでした。index の中身を確認してください。" >&2
  exit 1
fi

echo "署名対象の子digest一覧:"
echo "${CHILD_DIGESTS}"

# 取り出した子digestそれぞれに notation sign を実行
for DIGEST in ${CHILD_DIGESTS}; do
  echo "----- 署名: ${ECR_URI}@${DIGEST} -----"
  notation sign "${ECR_URI}@${DIGEST}" \
    --plugin "com.amazonaws.signer.notation.plugin" \
    --id "${SIGNING_PROFILE_ARN}"
done

echo "===== 子manifest個別署名 完了 ====="
