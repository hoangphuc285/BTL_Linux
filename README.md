# Thiết kế và Triển khai Mạng WireGuard VPN An toàn với Cấu hình Tự động trên Ubuntu Linux

![OS](https://img.shields.io/badge/OS-Ubuntu%2026.04.1%20LTS-E95420?logo=ubuntu&logoColor=white)
![VPN](https://img.shields.io/badge/VPN-WireGuard-88171A?logo=wireguard&logoColor=white)
![Automation](https://img.shields.io/badge/Automation-Bash%20Shell%20(12%20Scripts)-4EAA25?logo=gnu-bash&logoColor=white)
![OpenSource](https://img.shields.io/badge/Custom%20Build-wireguard--tools%20(a58888d)-blue)

Kho mã nguồn và tài liệu thực hành Bài tập lớn môn Hệ điều hành Linux / Quản trị mạng. Dự án xây dựng hạ tầng mạng riêng ảo (VPN) sử dụng **WireGuard** trên nền tảng **Ubuntu 26.04.1 LTS**, tích hợp bộ công cụ tự động hóa bằng **Shell Script**, dịch vụ **DNS nội bộ (`dnsmasq`)**, **cứng hóa bảo mật (SSH & UFW)**, và **tùy biến/biên dịch lại mã nguồn mở `wireguard-tools`**.

---

## 1. Tiến độ thực hiện dự án

### Đã hoàn thành
- [x] **Giai đoạn 0 – Chuẩn bị môi trường Lab:** Triển khai 3 máy ảo Ubuntu 26.04.1 LTS trên VirtualBox (2 card mạng NAT + Host-only), cấu hình Netplan IP tĩnh, cấp lại `machine-id` và SSH host keys riêng biệt.
- [x] **Giai đoạn 1 – Triển khai WireGuard & Tự động hóa:** Dựng VPN Server và 2 Client; phát triển bộ script quản lý vòng đời client (`add_client.sh`, `remove_client.sh`), đổi tham số động không ngắt kết nối qua `wg syncconf` (`set_param.sh`, `client_tunnel.sh`).
- [x] **Giai đoạn 2 – Định tuyến, NAT & Cứng hóa bảo mật:**
  - Hỗ trợ song song **Split-tunnel** và **Full-tunnel** kèm NAT Masquerade ra Internet.
  - Thiết lập tường lửa **UFW** mặc định chặn (`deny incoming/routed`), chỉ mở các luồng hợp lệ.
  - Triển khai **DNS nội bộ (`dnsmasq`)** cho miền `vpn.lan` trên giao diện `10.8.0.1` với script quản trị riêng (`dns_manage.sh`).
  - **Cứng hóa SSH** (`10-hardening.conf`): chỉ xác thực bằng khóa Ed25519, vô hiệu hóa đăng nhập `root` và mật khẩu, xử lý tự động `ssh.socket` khi đổi cổng.
- [x] **Giai đoạn 3 – Tùy biến & Biên dịch mã nguồn mở (`wireguard-tools`):**
  - Tải mã nguồn gốc (commit `ba8556c`), sửa đổi hàm hiển thị trạng thái bắt tay trong `show.c` (thêm nhãn màu `[ACTIVE]` / `[STALE]` theo ngưỡng 180 giây) và chuỗi phiên bản trong `wg.c`.
  - Biên dịch, cài đặt độc lập vào `/usr/local/bin/wg` thông qua script `build_wg_tools.sh` và xuất bản vá `.patch`.
- [x] **Quản lý phiên bản & Bảo mật kho mã:** Cấu hình `.gitignore` loại trừ tuyệt đối khóa riêng và tệp nhạy cảm; lưu các mốc Snapshot VirtualBox (`06-opensource-wg`).

### Đang thực hiện & Kế hoạch tiếp theo
- [ ] **Hoàn thiện kiểm thử bổ sung:** Xác nhận kiểm thử chống rò rỉ IPv6 khi bật Full-tunnel (`TC18`) và chuyển đổi qua lại chế độ tunnel trên client (`TC19`).
- [ ] **Giai đoạn 4 – Ảo hóa & Container/Cloud:** Triển khai cụm Kubernetes nhẹ (`k3s` hoặc `MicroK8s`), chạy dịch vụ dạng Pod, thực hiện scale và rolling update.
- [ ] **Mở rộng dịch vụ Server:** Bổ sung dịch vụ nội bộ (ví dụ Nginx Web Server chỉ truy cập qua VPN) theo yêu cầu chốt của giảng viên.

---

## 2. Kiến trúc mạng Lab

Hệ thống gồm 3 máy ảo chạy trên VirtualBox, kết nối qua mạng nội bộ Host-only (`192.168.56.0/24`) và tạo đường hầm VPN trên dải `10.8.0.0/24`:

| Máy ảo | Hostname | IP Host-only (`enp0s8`) | IP VPN (`wg0`) | Vai trò |
| :--- | :--- | :--- | :--- | :--- |
| **VM 1** | `wg-server` | `192.168.56.10` | `10.8.0.1/24` | WireGuard Server, NAT Gateway, UFW, DNS (`dnsmasq`), SSH |
| **VM 2** | `wg-client1` | `192.168.56.11` | `10.8.0.2/32` | Client cấu hình ban đầu, kiểm thử chuyển đổi Split / Full-tunnel |
| **VM 3** | `wg-client2` | `192.168.56.12` | `10.8.0.3/32` | Client cấp phát tự động 100% bằng script & kiểm thử trạng thái `[STALE]` |

> **Lưu ý hạ tầng:** Cả 3 VM đều có card NAT (`enp0s3`) dùng chung IP `10.0.2.15` để truy cập Internet, do đó `Endpoint` kết nối VPN được định tuyến qua card Host-only `192.168.56.10:51820`.

---

## 3. Cấu trúc kho lưu trữ

```text
BTL_Linux/
├── cloud/                  # Tài nguyên triển khai Kubernetes/k3s (Giai đoạn 4)
├── configs/                # Tệp cấu hình mẫu đã lược bỏ khóa bí mật
│   └── wg0-server.conf.template
├── docs/                   # Tài liệu báo cáo và bản vá mã nguồn mở
│   └── 0001-wg-show-add-ACTIVE-STALE-handshake-label-custom-vers.patch
├── opensource/             # Thư mục chứa mã nguồn wireguard-tools cục bộ (bị loại trừ bởi .gitignore)
├── scripts/                # Bộ 12 kịch bản Shell tự động hóa quản trị hệ thống
│   ├── common.sh           # Thư viện hàm dùng chung (backup, wg syncconf, ghi server.env)
│   ├── install_wg.sh       # Cài đặt và khởi tạo WireGuard Server (idempotent)
│   ├── add_client.sh       # Tạo client mới (sinh khóa, PSK, IP tự động, file .conf & mã QR)
│   ├── remove_client.sh    # Thu hồi quyền truy cập và xóa peer an toàn
│   ├── set_param.sh        # Thay đổi động Port, MTU, Endpoint, DNS trên Server
│   ├── client_tunnel.sh    # Chuyển đổi chế độ Split-tunnel <-> Full-tunnel cho Client
│   ├── status_check.sh     # Giám sát tổng thể dịch vụ, IP forwarding, cổng UDP và các Peer
│   ├── harden_firewall.sh  # Thiết lập quy tắc tường lửa UFW mặc định chặn
│   ├── install_dns.sh      # Cài đặt và cấu hình dnsmasq nội bộ (vpn.lan)
│   ├── dns_manage.sh       # Quản lý bản ghi DNS cục bộ, forwarder và cache
│   ├── ssh_param.sh        # Cứng hóa SSH và thay đổi cổng SSH an toàn (hỗ trợ ssh.socket)
│   └── build_wg_tools.sh   # Tự động tải, biên dịch, cài đặt, gỡ và xác minh wireguard-tools
├── .gitignore              # Quy tắc chặn tệp khóa (*.key), cấu hình thật (wg0.conf) và mã nguồn ngoài
└── README.md
```

---

## 4. Hướng dẫn sử dụng bộ Script tự động hóa

Cấp quyền thực thi cho toàn bộ script trong thư mục `scripts/`:

```bash
cd ~/wg-project/scripts
chmod +x *.sh
```

### Các lệnh vận hành thường dùng

```bash
# 1. Cài đặt WireGuard Server & Cứng hóa Firewall
sudo ./install_wg.sh
sudo ./harden_firewall.sh

# 2. Quản lý Client VPN
sudo ./add_client.sh client2          # Tạo cấu hình + mã QR cho client2
sudo ./remove_client.sh client2       # Xóa client2 và tự động backup wg0.conf

# 3. Thay đổi tham số động (không ngắt kết nối các client đang chạy)
sudo ./set_param.sh mtu 1380
sudo ./set_param.sh port 51820

# 4. Quản trị dịch vụ DNS nội bộ (miền vpn.lan)
sudo ./install_dns.sh
sudo ./dns_manage.sh add web 10.8.0.1 # Tạo bản ghi web.vpn.lan -> 10.8.0.1
sudo ./dns_manage.sh list

# 5. Cứng hóa SSH & Kiểm tra trạng thái tổng thể
sudo ./ssh_param.sh show
sudo ./status_check.sh
```

---

## 5. Tùy biến & Biên dịch mã nguồn mở (`wireguard-tools`)

Dự án thực hiện nghiên cứu quy trình biên dịch C (`gcc` $\rightarrow$ file đối tượng `.o` $\rightarrow$ liên kết `wg`) từ kho gốc `git.zx2c4.com/wireguard-tools` (mốc commit `ba8556c`) và phát triển nhánh tùy chỉnh `custom-wg` (commit `a58888d`):

1. **Cải tiến hiển thị trạng thái kết nối (`src/show.c`):** Tính toán thời gian từ lần bắt tay gần nhất (`time(NULL) - peer->last_handshake_time.tv_sec`). Nếu vượt quá ngưỡng **180 giây** (`HANDSHAKE_STALE_SECONDS`), lệnh `wg show` hiển thị cảnh báo **`[STALE]`** (màu đỏ); ngược lại hiển thị **`[ACTIVE]`** (màu xanh).
2. **Định danh phiên bản (`src/wg.c`):** Bổ sung chuỗi `(custom build)` vào kết quả của `wg --version`.

### Quy trình biên dịch và đối chiếu toàn vẹn

```bash
cd ~/wg-project/scripts
./build_wg_tools.sh fetch     # Tải mã nguồn gốc
./build_wg_tools.sh build     # Biên dịch trong subshell (giữ đúng ngữ cảnh Git cho Makefile)
./build_wg_tools.sh install   # Cài đặt vào /usr/local/bin/wg (không ghi đè bản hệ thống)
hash -r                       # Làm mới bộ nhớ đệm đường dẫn của Bash
./build_wg_tools.sh verify    # Kiểm tra phiên bản và mã băm SHA-256
```

| Tiêu chí đối chiếu | Bản gốc hệ thống (`/usr/bin/wg`) | Bản biên dịch tùy chỉnh (`/usr/local/bin/wg`) |
| :--- | :--- | :--- |
| **Phiên bản (`--version`)** | `v1.0.20250521` | `v1.0.20260223-10-ga58888d-dirty (custom build)` |
| **Mã băm SHA-256** | `8f29ae52...95efcd4` | `8d552360...8a1f019` |
| **Đầu ra `wg show`** | Chỉ hiển thị thời gian handshake | Hiển thị kèm nhãn **`[ACTIVE]`** hoặc **`[STALE]`** |
| **Bản vá lưu trữ** | — | `docs/0001-wg-show-add-ACTIVE-STALE-handshake-label-custom-vers.patch` |

---

## 6. Bảo mật & Giải quyết sự cố kỹ thuật tiêu biểu

* **Bảo vệ thông tin nhạy cảm:** Toàn bộ khóa riêng (`*.key`), cấu hình máy chủ (`wg0.conf`), thư mục khóa khách (`clients/`), biến môi trường (`server.env`) và tệp sao lưu (`*.bak.*`) đều được loại trừ qua `.gitignore` và kiểm tra lịch sử Git sạch 100%.
* **Xử lý vòng lặp khởi động `systemd` giữa `dnsmasq` và `wg-quick@wg0`:** Loại bỏ drop-in phụ thuộc cứng gây deadlock với `nss-lookup.target`, chuyển sang sử dụng tham số `bind-dynamic` trong cấu hình `dnsmasq` để dịch vụ tự động lắng nghe trên `10.8.0.1` ngay khi giao diện `wg0` sẵn sàng sau reboot.
* **Khắc phục lỗi mất mã commit khi gọi `make -C`:** Chạy lệnh biên dịch bên trong subshell `(cd "$SRC_DIR/src" && make ...)` trong `build_wg_tools.sh` để biến `$(PWD)` của `Makefile` trỏ đúng vào kho `.git` của `wireguard-tools`.
