package com.example;

import com.sun.net.httpserver.HttpServer;
import java.io.IOException;
import java.io.OutputStream;
import java.net.InetSocketAddress;
import java.nio.charset.StandardCharsets;

public class App {
    public static void main(String[] args) throws IOException {
        int port = 8080;

        HttpServer server = HttpServer.create(new InetSocketAddress(port), 0);

        // ヘルスチェック兼トップページ（ALB のヘルスチェックパス "/" に 200 を返す）
        server.createContext("/", exchange -> {
            String response = "Hello from Corretto 25 with OpenTelemetry!";
            byte[] body = response.getBytes(StandardCharsets.UTF_8);
            exchange.getResponseHeaders().set("Content-Type", "text/plain; charset=UTF-8");
            exchange.sendResponseHeaders(200, body.length);
            try (OutputStream os = exchange.getResponseBody()) {
                os.write(body);
            }
        });

        // デフォルトのスレッドプールで処理
        server.setExecutor(null);
        server.start();

        System.out.println("Server started on port " + port);
    }
}
