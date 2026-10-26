# BTL Linux: WireGuard VPN Lab, Internal DNS & SSH Hardening

Dự án xây dựng và triển khai hệ thống mạng riêng ảo (VPN) WireGuard trên môi trường ảo hóa VirtualBox, tích hợp quản lý DNS nội bộ qua Dnsmasq và gia cố bảo mật dịch vụ SSH.

---

## 📌 Mô Hình Mạng & Phân Mạng (Topology)

| Tên Máy VirtualBox | Vai Trò (Role) | Card Host-Only (IP) | WireGuard IP (`wg0`) | Dịch Vụ Chính |
| :--- | :--- | :--- | :--- | :--- |
| **`wg-server`** | VPN Gateway & DNS Server | `192.168.56.10/24` | `10.8.0.1/24` | WireGuard, Dnsmasq, SSH (Key-based) |
| **`wg-client1`** | VPN Client 1 | N/A | `10.8.0.2/24` | WireGuard Client, DNS Client |
| **`wg-client2`** | VPN Client 2 | N/A | `10.8.0.3/24` | WireGuard Client |

* **Dải IP VPN Internal:** `10.8.0.0/24`
* **Tên miền nội bộ:** `*.vpn.lan` (Ví dụ: `web.vpn.lan` $\rightarrow$ `10.8.0.1`)

---

## 🚀 Các Tính Năng Đã Triển Khai

### Giai Đoạn 1: WireGuard VPN & Network Routing
- Khởi tạo và thiết lập giao diện WireGuard `wg0` trên Server và các Clients.
- Cấu hình chuyển tiếp dữ liệu (IP Forwarding) & NAT cho phép Client truy cập qua VPN.
- Thiết lập tường lửa UFW kiểm soát lưu lượng trên giao diện `wg0` và cổng WireGuard (UDP `51820`).

### Giai Đoạn 2: Internal DNS & SSH Hardening
- **Quản lý DNS nội bộ (Dnsmasq):**
  - Chỉ cho phép Dnsmasq lắng nghe truy vấn trên giao diện `10.8.0.1` (`wg0`).
  - Phân giải tên miền nội bộ (`web.vpn.lan`) và chuyển tiếp (forwarding) truy vấn Internet (`ubuntu.com`).
  - Tự động khắc phục điều kiện khởi động: Dnsmasq tự động lên sau khi giao diện `wg0` sẵn sàng.
  - Xây dựng script `dns_manage.sh` thêm/xóa bản ghi và thay đổi DNS forwarder linh hoạt.
- **Gia cố bảo mật dịch vụ SSH:**
  - Bắt buộc xác thực bằng cặp khóa **Ed25519** (`publickey`).
  - Vô hiệu hóa đăng nhập `root` (`PermitRootLogin no`) và vô hiệu hóa đăng nhập mật khẩu (`PasswordAuthentication no`).
  - Xây dựng script `ssh_param.sh` để kiểm tra thông số và đổi cổng SSH tự động (đồng bộ luật UFW).

---

## 📂 Cấu Trúc Thư Mục Dự Án

```text
wg-project/
├── configs/             # Lưu trữ file cấu hình hệ thống
│   ├── wg0.conf         # Cấu hình WireGuard Server
│   └── dnsmasq.conf     # Cấu hình Dnsmasq DNS
├── scripts/             # Các script quản trị tự động
│   ├── dns_manage.sh    # Script quản lý bản ghi & forwarder DNS
│   └── ssh_param.sh     # Script quản lý & thay đổi cổng SSH
└── README.md            # Tài liệu hướng dẫn dự án
