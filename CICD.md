# CI/CD Pipeline Guide (Gitea Actions)

Tài liệu hướng dẫn cơ chế CI/CD tự động hóa dành cho dự án **Library Check-in System** trên nền tảng Gitea.

---

## 1. Tổng quan kiến trúc CI/CD

Quy trình CI/CD được thiết kế để giải quyết bài toán: **Tối ưu tài nguyên máy cá nhân (Local)**, giảm thiểu dung lượng ổ đĩa bị chiếm dụng do cache Docker, Maven và Android SDK.

```
                  ┌─────────────────────────────────────────┐
                  │ Push code vào branch: main              │
                  └────────────────────┬────────────────────┘
                                       │
                                       ▼
                  ┌─────────────────────────────────────────┐
                  │ Gitea Actions Runner (Cloud / Server)   │
                  └──────┬──────────────────┬──────────────┬┘
                         │                  │              │
                         ▼                  ▼              ▼
               ┌──────────────────┐┌──────────────────┐┌──────────────────┐
               │  Spring Boot     ││  FastAPI (AI)    ││  Flutter App     │
               │  Build & Package ││  Build & Package ││  Build Android   │
               │  Docker Image    ││  Docker Image    ││  Release APK     │
               └─────────┬────────┘└────────┬─────────┘└────────┬─────────┘
                         │                  │                   │
                         ▼                  ▼                   ▼
           ┌─────────────────────────────────────────┐ ┌──────────────────┐
           │ Gitea Container Registry                │ │ Gitea Artifacts  │
           │ • git.lim-dxlab.space/.../backend       │ │ • app-release.apk│
           │ • git.lim-dxlab.space/.../ai-service    │ └────────┬─────────┘
           └─────────────────────┬───────────────────┘          │
                                 │                              │
                                 ▼                              ▼
                 ┌───────────────────────────────┐ ┌──────────────────────┐
                 │ Máy tính Local                │ │ Điện thoại Android   │
                 │ docker compose pull           │ │ Tải file APK về      │
                 │ (Không tốn GB build cache)    │ │ và cài đặt trực tiếp │
                 └───────────────────────────────┘ └──────────────────────┘
```

---

## 2. Cấu hình Workflows (Tách riêng theo Path Filtering)

Mỗi service sở hữu một workflow riêng biệt, chỉ kích hoạt khi có thay đổi trong thư mục tương ứng trên nhánh **`main`** (tránh build thừa các service không liên quan):

| Workflow File | Path Trigger | Nhiệm vụ | Output |
|---|---|---|---|
| **`.gitea/workflows/backend.yml`** | `backend/**` | Build image Spring Boot (Java 21) | `git.lim-dxlab.space/tsubasaozora/backend:latest` |
| **`.gitea/workflows/ai-service.yml`** | `ai-service/**` | Build image Python FastAPI | `git.lim-dxlab.space/tsubasaozora/ai-service:latest` |
| **`.gitea/workflows/client.yml`** | `client/**` | Build release Android APK qua Flutter SDK | `app-release.apk` (Lưu tại Gitea Artifacts trong 14 ngày) |

---

## 3. Hướng dẫn sử dụng cho Developer

### A. Chạy hệ thống trên máy tính Local (Không cần build)

Nhờ có CI/CD tự build sẵn Docker image, máy tính của bạn không cần cài đặt JDK, Maven, Python venv hay chạy `docker build` nặng hàng chục GB:

1. **Chuẩn bị file biến môi trường:**
   ```bash
   cp .env.example .env
   ```

2. **Kéo image mới nhất đã build bởi CI/CD về máy:**
   ```bash
   docker compose -f docker-compose.local.yml pull
   ```

3. **Khởi chạy container:**
   ```bash
   docker compose -f docker-compose.local.yml up -d
   ```

4. **Kiểm tra trạng thái các container:**
   ```bash
   docker compose -f docker-compose.local.yml ps
   ```

---

### B. Cài đặt và thử nghiệm trên Điện thoại Android

Không cần cài đặt Android Studio hay Android SDK trên máy tính:

1. Truy cập repo trên trình duyệt web: `https://git.lim-dxlab.space/tsubasaozora/LibIOG6`.
2. Vào tab **Actions** -> Chọn commit mới nhất đã chạy xong.
3. Ở góc phải mục **Artifacts**, bấm tải file **`app-release-apk`** (giải nén ra file `app-release.apk`).
4. Cài file `.apk` vào điện thoại Android và mở app.

---

### C. Kết nối điện thoại với Backend đang chạy trên máy tính

Khi mở app trên điện thoại, app cần kết nối tới Backend Spring Boot đang chạy trong Docker của laptop:

#### Cách 1: Kết nối qua cáp USB (Khuyên dùng - Ổn định nhất)
1. Bật **USB Debugging** trên điện thoại Android và cắm cáp vào máy tính.
2. Chạy lệnh:
   ```bash
   adb reverse tcp:8080 tcp:8080
   ```
3. Trong Flutter app, bạn có thể gọi trực tiếp `http://localhost:8080`.

#### Cách 2: Kết nối qua mạng Wi-Fi nội bộ
1. Đảm bảo điện thoại và laptop kết nối cùng một mạng Wi-Fi.
2. Tìm địa chỉ IP của laptop:
   - macOS: `ipconfig getifaddr en0` (ví dụ ra: `192.168.1.15`).
3. Điền URL API trên app là: `http://192.168.1.15:8080`.

---

## 4. Quản trị & Yêu cầu hệ thống (Server Gitea)

Để pipeline chạy thành công, server Gitea cần đáp ứng:
1. **Gitea Actions:** Bật tính năng Actions trong Repository Settings (`Settings` -> `Repository` -> tích chọn `Enable Repository Actions`).
2. **Runner (`act_runner`):** Server Gitea cần có ít nhất 1 `act_runner` đang online và hỗ trợ label `ubuntu-latest`.
3. **Container Registry:** Token mặc định `${{ secrets.GITHUB_TOKEN }}` trong workflow đã được cấp quyền đọc/ghi Package Registry của repo.
