# Hướng dẫn sử dụng Flow Kit

Dành cho người muốn làm video bằng AI mà **không cần biết lập trình**.

Tài liệu này giải thích Flow Kit bằng ngôn ngữ đời thường: cài lần đầu, mỗi ngày mở máy thế nào, nói chuyện với trợ lý AI ra sao, và khi nào nên dừng lại nhờ người khác.

> Tài liệu kỹ thuật cho lập trình viên nằm ở [README.md](../README.md).  
> Trợ lý AI đọc [CLAUDE.md](../CLAUDE.md) (Claude Code), skill/rule trong `.agents/` (Antigravity), hoặc `.opencode/` (OpenCode).  
> Bạn chỉ cần đọc **file này**.

---

## Mục lục

1. [Flow Kit làm gì?](#1-flow-kit-làm-gì)
2. [Bạn cần chuẩn bị gì?](#2-bạn-cần-chuẩn-bị-gì)
3. [Hiểu hệ thống trong 2 phút](#3-hiểu-hệ-thống-trong-2-phút)
4. [Cài đặt lần đầu](#4-cài-đặt-lần-đầu)
5. [Mỗi ngày mở máy làm việc](#5-mỗi-ngày-mở-máy-làm-việc)
6. [Tạo một video từ ý tưởng](#6-tạo-một-video-từ-ý-tưởng)
7. [Các lệnh hay dùng](#7-các-lệnh-hay-dùng)
8. [Cách kể chuyện để AI hiểu](#8-cách-kể-chuyện-để-ai-hiểu)
9. [Xem tiến độ trên bảng điều khiển](#9-xem-tiến-độ-trên-bảng-điều-khiển)
10. [Sự cố thường gặp](#10-sự-cố-thường-gặp)
11. [Giới hạn cần biết](#11-giới-hạn-cần-biết)
12. [Thuật ngữ](#12-thuật-ngữ)
13. [Không mua Claude: DeepSeek Flash + Qwen 3.7 Plus](#13-không-mua-claude-deepseek-flash--qwen-37-plus)
14. [Video kiểu Vox / motion graphic (rẻ, phù hợp UAT)](#14-video-kiểu-vox--motion-graphic-rẻ-phù-hợp-uat)
15. [Dùng Google Antigravity 2.0](#15-dùng-google-antigravity-20)
16. [Dùng OpenCode](#16-dùng-opencode)

---

## 1. Flow Kit làm gì?

Flow Kit giúp bạn **làm video AI có nhân vật nhìn giống nhau xuyên suốt**, thay vì tự ngồi trên website Google Flow bấm từng cảnh.

Bạn mô tả ý tưởng bằng tiếng Việt (hoặc tiếng Anh). Trợ lý AI sẽ:

1. Tách câu chuyện thành nhân vật, địa điểm, đạo cụ
2. Tạo **ảnh mẫu** (để mặt / quần áo / bối cảnh không đổi)
3. Tạo **ảnh từng cảnh**
4. Biến mỗi ảnh thành **clip khoảng 8 giây**
5. (Tuỳ chọn) Lồng tiếng thuyết minh, nhạc, thumbnail, đăng YouTube
6. Ghép các clip thành **một file video hoàn chỉnh**

Ví dụ kết quả: một phim ngắn 24 giây gồm 3 cảnh — mèo vũ trụ đáp xuống hành tinh kẹo, nếm sông sô-cô-la, cắm cờ trên núi kẹo dẻo — con mèo trông **cùng một con** ở cả 3 cảnh.

<p align="center">
  <img src="images/scene_nk_doctor_surgery.jpg" width="180" alt="Bác sĩ trong phòng mổ" />
  <img src="images/scene_nk_doctor_operating.jpg" width="180" alt="Bác sĩ đang phẫu thuật" />
  <img src="images/scene_nk_doctor_interview1.jpg" width="180" alt="Bác sĩ phỏng vấn" />
  <img src="images/scene_nk_doctor_interview2.jpg" width="180" alt="Bác sĩ mỉm cười" />
</p>

<p align="center"><sub>Cùng một nhân vật bác sĩ qua 4 cảnh khác nhau — nhờ ảnh mẫu.</sub></p>

**Flow Kit không phải app bấm nút “Tạo video” một phát xong.** Nó là bộ máy chạy trên máy bạn, còn “người điều khiển” là một trợ lý AI trong cửa sổ chat — **Claude Code**, **Google Antigravity 2.0**, hoặc **OpenCode**. Bạn nói chuyện; trợ lý gõ lệnh giúp.

---

## 2. Bạn cần chuẩn bị gì?

### Bắt buộc

| Thứ | Để làm gì | Ghi chú |
|-----|-----------|---------|
| Máy tính | Chạy phần mềm | macOS hoặc Windows 10/11. Windows: **PowerShell** (`setup.ps1`) hoặc **WSL** (xem bước 4) |
| [Google Chrome](https://www.google.com/chrome/) | Cài extension của Flow Kit | Extension **không** có trên Chrome Web Store — phải nạp tay |
| Tài khoản Google đã dùng được [Google Flow](https://labs.google/fx/tools/flow) | Tạo ảnh và video | Cần quyền / credit trên Google Flow. Không có tài khoản Flow thì hệ thống không tạo được media |
| Trợ lý AI: [Claude Code](https://code.claude.com/docs/en/overview), [Antigravity 2.0](https://antigravity.google/), hoặc [OpenCode](https://opencode.ai/) | Điều khiển Flow Kit bằng chat + lệnh `/fk-…` | Chọn **một**. Claude: [phần 4.6](#46-cài-claude-code-nếu-chưa-có) / [phần 13](#13-không-mua-claude-deepseek-flash--qwen-37-plus). Antigravity: [phần 15](#15-dùng-google-antigravity-20). OpenCode: [phần 16](#16-dùng-opencode) |
| Python 3.10+ và ffmpeg | Máy “bếp” phía sau | Script cài đặt sẽ kiểm tra và hướng dẫn nếu thiếu |

### Nên có

- Ổn định mạng (mỗi clip video mất 2–5 phút)
- Credit Google Flow còn đủ (ảnh rẻ hơn video; upscale 4K tốn hơn)
- Ý tưởng rõ: ai là nhân vật, xảy ra ở đâu, khoảng bao nhiêu cảnh

### Không cần

- Biết lập trình
- Gõ lệnh `curl` hay đọc API
- Tự vẽ nhân vật (AI vẽ ảnh mẫu giúp bạn)

---

## 3. Hiểu hệ thống trong 2 phút

Hãy nghĩ Flow Kit như một **xưởng phim nhỏ trên máy bạn**.

```
Bạn nói chuyện với Claude Code, Antigravity hoặc OpenCode
        ↓
Trợ lý AI ra lệnh cho “máy chủ cục bộ” (cổng 8100)
        ↓
Máy chủ nhờ extension Chrome nói chuyện với Google Flow
        ↓
Google Flow vẽ ảnh / làm clip
        ↓
Máy bạn tải về và ghép thành file video
```

Ba thứ phải **cùng bật** thì mới làm được việc:

1. **Chrome** đang mở trang Google Flow và **đã đăng nhập**
2. **Extension Flow Kit** đã được nạp và thấy “đã kết nối”
3. **Agent** (phần mềm Python) đang chạy trong một cửa sổ Terminal

Thiếu một trong ba → không tạo được ảnh/video.

### Vì sao cần “ảnh mẫu”?

AI video hay đổi mặt nhân vật mỗi cảnh. Flow Kit khắc phục bằng cách:

1. Vẽ **một lần** khuôn mặt / trang phục / địa điểm
2. Mỗi cảnh sau chỉ mô tả **hành động**, rồi gửi kèm ảnh mẫu đó

Vì vậy khi kể chuyện, bạn tách hai việc:

- **Ngoại hình** = mô tả nhân vật / nơi chốn (tóc, quần áo, màu sắc) — **một bộ đồ mặc định**
- **Hành động** = nhân vật đang làm gì trong cảnh này — **không lặp lại** mắt mũi quần áo

---

## 4. Cài đặt lần đầu

Làm **một lần**. Nếu đã có người cài sẵn trên máy bạn, nhảy tới [phần 5](#5-mỗi-ngày-mở-máy-làm-việc).

### 4.1. Lấy mã nguồn về máy

Cần có thư mục dự án trên máy (thường tên `flowkit` hoặc `google-flow-agent`).

- Nếu bạn nhận link GitHub: nhờ người rành bấm **Code → Download ZIP** rồi giải nén, **hoặc** clone bằng Git.
- Ghi nhớ đường dẫn thư mục đó. Mọi lệnh sau này đều chạy **bên trong** thư mục này.

### 4.2. Windows: PowerShell (khuyến nghị) hoặc WSL

**Cách A — PowerShell native (Windows 10 / 11):** mở **PowerShell** trong thư mục dự án (không dùng CMD):

```
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
.\setup.ps1
```

Cần Python 3.10+ từ [python.org](https://www.python.org/downloads/) (bật “Add python.exe to PATH”, **không** dùng bản Microsoft Store) và ffmpeg (`winget install Gyan.FFmpeg`). Mở cửa sổ PowerShell **mới** sau khi cài ffmpeg.

**Cách B — WSL:** nếu muốn môi trường Linux (TTS GPU, statusline Claude):

```
wsl --install
```

Khởi động lại máy nếu được yêu cầu. Sau đó mở **Ubuntu** — mọi lệnh `./setup.sh` gõ trong cửa sổ Ubuntu.

macOS: bỏ qua bước này, dùng ứng dụng **Terminal**.

### 4.3. Chạy script cài đặt

- **Windows PowerShell:** `.\setup.ps1` (bước 4.2 cách A đã chạy rồi thì nhảy tới 4.4).
- **macOS / Linux / WSL:** trong Terminal, vào thư mục dự án rồi chạy:

```
./setup.sh
```

Script sẽ kiểm tra Python, ffmpeg, Chrome, tạo môi trường ảo `venv`, cài thư viện.

- Thấy `Setup complete!` → ổn.
- Báo thiếu phần mềm → cài đúng thứ nó chỉ, rồi chạy lại script.

Ví dụ trên Ubuntu / WSL nếu thiếu Python hoặc ffmpeg:

```
sudo apt update
sudo apt install python3 python3-pip python3-venv ffmpeg
```

Trên macOS (nếu đã có [Homebrew](https://brew.sh)):

```
brew install python@3.12 ffmpeg
```

### 4.4. Nạp extension vào Chrome

1. Mở Chrome, gõ vào thanh địa chỉ: `chrome://extensions` rồi Enter
2. Bật **Developer mode** (góc trên bên phải)
3. Bấm **Load unpacked** / **Tải tiện ích đã giải nén**
4. Chọn thư mục `extension` **bên trong** thư mục Flow Kit (không chọn nhầm thư mục cha)

Bạn sẽ thấy một thẻ extension Flow Kit. Giữ nguyên, đừng tắt.

<p align="center">
  <img src="images/extension_screenshot.jpg" width="720" alt="Giao diện extension Flow Kit cạnh Google Flow" />
</p>

### 4.5. Đăng nhập Google Flow

Mở tab mới: [https://labs.google/fx/tools/flow](https://labs.google/fx/tools/flow)

Đăng nhập tài khoản Google **đã có quyền dùng Flow**. **Giữ tab này mở** khi làm video.

### 4.6. Cài Claude Code (nếu chưa có)

Làm theo hướng dẫn chính thức: [Claude Code](https://code.claude.com/docs/en/overview).

Sau khi cài, trong Terminal (đang đứng trong thư mục Flow Kit) gõ:

```
claude
```

Lần đầu có thể hỏi đăng nhập. Xong rồi bạn có cửa sổ chat — đây là nơi bạn làm việc hàng ngày.

Nếu **không mua** gói Claude.ai, đừng đăng nhập subscription. Làm theo [phần 13](#13-không-mua-claude-deepseek-flash--qwen-37-plus) để Claude Code dùng **DeepSeek V4 Flash** + **Qwen 3.7 Plus**.

Muốn dùng **Antigravity** hoặc **OpenCode** thay Claude Code: bỏ qua bước này và làm [phần 15](#15-dùng-google-antigravity-20) hoặc [phần 16](#16-dùng-opencode). Chrome + agent Python vẫn bắt buộc như cũ.

### 4.7. Kiểm tra “cả nhà đã vào chỗ”

Mở **một cửa sổ Terminal khác** (để dành cửa sổ Claude), vào thư mục Flow Kit:

```
source venv/bin/activate        # macOS / Linux / WSL
python -m agent.main
```

Windows PowerShell:

```
.\venv\Scripts\Activate.ps1
python -m agent.main
```

Cửa sổ này phải **để chạy**, đừng đóng. Rồi mở cửa sổ thứ ba, gõ:

```
curl -s http://127.0.0.1:8100/health
```

Windows PowerShell: `Invoke-RestMethod http://127.0.0.1:8100/health`

Kết quả tốt trông giống:

```
{"extension_connected": true}
```

Nếu `extension_connected` là `false`:

- Tab Google Flow đã mở và đã login chưa?
- Vào `chrome://extensions` bấm **reload** (icon tròn) trên thẻ Flow Kit
- Agent (`python -m agent.main`) còn đang chạy không?

Khi cả ba thứ xanh, bạn sẵn sàng làm video.

---

## 5. Mỗi ngày mở máy làm việc

Làm theo thứ tự này mỗi lần ngồi làm:

1. Mở **Chrome** → mở [Google Flow](https://labs.google/fx/tools/flow) → chắc chắn đã login
2. Mở Terminal, vào thư mục Flow Kit, chạy agent:

   ```
   source venv/bin/activate        # macOS / Linux / WSL
   python -m agent.main
   ```

   Windows PowerShell: `.\venv\Scripts\Activate.ps1` rồi `python -m agent.main`.

   Để cửa sổ này chạy ngầm. Thấy dòng kiểu `Flow Kit starting` là được.

3. (Tuỳ chọn) Kiểm tra sức khoẻ:

   ```
   curl -s http://127.0.0.1:8100/health
   ```

   Phải có `"extension_connected": true`.

4. Mở Terminal khác, vào cùng thư mục, chạy `claude`
5. Trong chat, nói ý tưởng hoặc gõ lệnh ở [phần 7](#7-các-lệnh-hay-dùng)

**Tắt máy / hết giờ:** trong cửa sổ agent bấm `Ctrl+C`, đóng Claude, có thể đóng tab Flow. Ngày mai lặp lại 5 bước trên. Dự án cũ vẫn còn trên máy, không mất.

---

## 6. Tạo một video từ ý tưởng

Đây là lộ trình chuẩn. Bạn **không cần nhớ tên lệnh** — có thể nói tiếng Việt, ví dụ: *“Tạo dự án mới: mèo vũ trụ Luna đáp xuống hành tinh kẹo, 3 cảnh, dọc, kiểu Pixar.”* Claude sẽ hỏi thêm rồi tự chạy các bước.

### Bước 0 — (Phim tài liệu / tin tức) Kiểm tra sự thật

Nếu video kể chuyện **có thật**, nói:

> Nghiên cứu giúp tôi chủ đề “…” trước khi viết kịch bản.

Trợ lý sẽ tìm nguồn, ghi file nghiên cứu, **không bịa** tên chiến dịch hay ngày tháng.

Phim hoạt hình / chuyện bịa: bỏ qua bước này.

### Bước 1 — Tạo dự án

Nói rõ 6 thứ (thiếu cái nào Claude sẽ hỏi):

1. **Tên dự án**
2. **Tóm tắt chuyện** (vài câu)
3. **Phong cách hình** — chọn một: hiện thực (`realistic`), Pixar 3D (`3d_pixar`), anime, stop-motion, Minecraft, sơn dầu
4. **Nhân vật** — tên + ngoại hình **một bộ đồ**
5. **Địa điểm / đạo cụ quan trọng** — nơi và đồ xuất hiện nhiều cảnh
6. **Số cảnh** và **ngang hay dọc** (YouTube dài = ngang; Shorts / Reels = dọc)

Ví dụ bạn nói:

> Dự án “Luna mèo vũ trụ”. Mèo trắng nhỏ mặc đồ phi hành gia cam, mũ kính tròn. Hành tinh toàn kẹo. 3 cảnh dọc, kiểu Pixar: đáp xuống → nếm sông sô-cô-la → cắm cờ trên núi kẹo dẻo.

Claude tạo *dự án* + *video* + *danh sách cảnh*. Bạn sẽ nhận mã dự án (kiểu `p-…`) — không cần thuộc lòng; nói “dự án vừa tạo” là đủ.

### Bước 2 — Tạo ảnh mẫu nhân vật / nơi chốn

> Tạo ảnh mẫu cho dự án này.

Đợi đến khi **mọi** nhân vật và địa điểm đều có ảnh. Xem ảnh: mặt có đúng ý không? Không ưng → bảo *“vẽ lại nhân vật Luna, mắt to hơn, mũ kính trong hơn.”*

**Đừng vội làm ảnh cảnh khi ảnh mẫu còn sai** — sai lúc này sẽ sai cả phim.

### Bước 3 — Tạo ảnh từng cảnh

> Tạo ảnh các cảnh.

Mỗi cảnh = một khung hình đầu. Kiểm tra: đúng người, đúng chỗ, mặt nhìn rõ (không cắt ngang mắt).

### Bước 4 — Tạo clip video

> Tạo video các cảnh.

Mỗi clip khoảng **8 giây**, mất **2–5 phút**. Có thể đi uống nước. Xong thì xem từng clip.

### Bước 5 — (Nên làm) Xem lại chất lượng

> Review video giúp tôi.

Cảnh kém (điểm thấp, mặt méo, hành động sai) sẽ được gợi ý sửa lời thoại máy quay rồi quay lại. Tối đa khoảng 2 vòng.

### Bước 6 — (Tuỳ chọn) Thuyết minh, nhạc, 4K

Tuỳ nhu cầu:

- “Viết lời thuyết minh và đọc thành tiếng”
- “Làm nhạc nền”
- “Nâng lên 4K” — chỉ khi tài khoản Flow đủ hạng (tier cao hơn)

### Bước 7 — Ghép thành file cuối

> Ghép các cảnh thành video hoàn chỉnh.

File thường nằm trong thư mục `output/…` trong dự án. Mở bằng trình phát video bình thường.

### Một lệnh thay vì từng bước

Khi đã quen, có thể nói:

> Chạy cả pipeline cho dự án này.

Claude sẽ tự làm các bước còn thiếu. Lần đầu nên làm từng bước để kịp xem ảnh mẫu.

---

## 7. Các lệnh hay dùng

Trong Claude Code, Antigravity hoặc OpenCode, gõ dấu `/` rồi chọn lệnh. Cũng có thể nói tiếng Việt tương đương.

### Làm phim (thứ tự này)

| Bạn gõ / nói | Việc xảy ra |
|--------------|-------------|
| `/fk-research` | Kiểm tra sự thật trước khi viết phim tài liệu |
| `/fk-create-project` | Tạo dự án, nhân vật, cảnh |
| `/fk-gen-refs` | Vẽ ảnh mẫu |
| `/fk-gen-images` | Vẽ ảnh từng cảnh |
| `/fk-gen-videos` | Làm clip 8 giây |
| `/fk-review-video` | Chấm điểm clip trước khi tốn credit upscale |
| `/fk-concat` | Tải về và ghép thành 1 file |

### Làm đẹp thêm

| Lệnh | Việc xảy ra |
|------|-------------|
| `/fk-gen-chain-videos` | Cảnh sau nối mượt từ cảnh trước (start–end frame) |
| `/fk-insert-scene` | Thêm cận cảnh / góc máy phụ |
| `/fk-gen-narrator` | Viết + đọc thuyết minh |
| `/fk-concat-fit-narrator` | Cắt clip cho khớp độ dài lời đọc |
| `/fk-gen-music` | Nhạc nền (Suno) |
| `/fk-thumbnail` | 4 mẫu thumbnail YouTube |
| `/fk-youtube-seo` | Tiêu đề, mô tả, tag |
| `/fk-youtube-upload` | Đăng YouTube |

### Khi lạc / khi hỏng

| Lệnh | Việc xảy ra |
|------|-------------|
| `/fk-status` | Xem dự án đang tới đâu, bước tiếp theo là gì |
| `/fk-switch-project` | Đổi dự án đang làm |
| `/fk-doctor` | **Gọi lệnh này khi có lỗi** — đừng tự đoán |
| `/fk-refresh-urls` | Ảnh/video hết hạn link (chữ ký Google hết hạn) |

---

## 8. Cách kể chuyện để AI hiểu

Viết như đang brief đạo diễn, không như đang viết tiểu thuyết.

### Nhân vật — chỉ ngoại hình, một bộ đồ

Tốt:

> Luna: mèo trắng nhỏ, mắt xanh to, bộ phi hành gia cam, mũ kính tròn, đuôi xù thò ra ngoài.

Xấu:

> Luna lúc thì mặc đồ dạ hội, lúc thì đồ thể thao, lúc thì phi hành gia, tính tình vui vẻ thích khám phá…

Trang phục đổi theo cảnh thì ghi **trong mô tả hành động của cảnh đó**, không nhồi vào ảnh mẫu.

### Cảnh — chỉ hành động + máy quay

Tốt:

> Luna quỳ bên Sông Sô-cô-la, nhúng một chân vào, mặt ngạc nhiên. Máy quay ngang tầm vai.

Xấu:

> Một chú mèo trắng nhỏ mắt xanh mặc đồ cam… (lặp ngoại hình — ảnh mẫu đã lo)

### Ngang hay dọc, phong cách

Nói từ đầu: “video dọc cho Shorts” hoặc “ngang cho YouTube dài”, và “kiểu Pixar” / “như phim tài liệu”. Cả phim **một phong cách** — đừng cảnh 1 anime, cảnh 2 hiện thực.

### Người nổi tiếng / chính trị gia

Google Flow hay **chặn** khi nhận ra mặt người nổi tiếng. Cách an toàn:

- Đặt tên nhân vật theo **vai trò tiếng Anh**, không dùng tên thật trong mô tả hình (ví dụ “The Commander”, không “Trump”)
- Mô tả tóc, dáng, quần áo — không nêu tên
- Ảnh mẫu nên **lưng hoặc nghiêng** nếu là chính khách rất quen mặt
- Lời **thuyết minh** (chỉ âm thanh) mới được nói tên thật

### Việc không nên đưa vào lời mô tả hình

Tránh từ dễ bị lọc: giết, máu, xác, nổ bom, tra tấn, trẻ em / em bé trong cảnh hình. Kể **không khí và hệ quả** (khói, đổ nát, căng thẳng) thay vì bạo lực trực tiếp.

---

## 9. Xem tiến độ trên bảng điều khiển

Ngoài chat Claude, có trang web trên máy bạn để nhìn từng cảnh.

Agent phải đang chạy. Mở Terminal mới:

```
cd dashboard
npm install
npm run dev
```

Trình duyệt mở [http://127.0.0.1:5173](http://127.0.0.1:5173).

Ở đây bạn xem:

- Dự án nào đang làm
- Cảnh nào xong ảnh mẫu / ảnh cảnh / video
- Trang **Hướng dẫn** (Guide) — trạng thái extension xanh/đỏ

<p align="center">
  <img src="images/dashboard_overview.png" width="720" alt="Màn hình tổng quan dashboard" />
</p>

Đổi ngôn ngữ giao diện ở dashboard nếu muốn tiếng Việt.

---

## 10. Sự cố thường gặp

Khi không chắc, trong Claude gõ **`/fk-doctor`** và dán nguyên câu lỗi.

| Bạn thấy gì | Thường vì sao | Làm gì |
|-------------|----------------|--------|
| `extension_connected: false` | Chrome / Flow / extension chưa sẵn | Mở lại tab Flow, reload extension, chắc agent đang chạy |
| Extension báo **Agent disconnected** | Chưa chạy `python -m agent.main` | Chạy lại agent, để cửa sổ đó mở |
| Extension báo **No token** | Chưa login Flow | Mở lại [Flow](https://labs.google/fx/tools/flow), đăng nhập |
| `NO_FLOW_KEY` | Giống trên | Login Flow, reload extension |
| `CAPTCHA` / `NO_FLOW_TAB` | Không có tab Flow | Để một tab Flow đang mở phía trước |
| `UNSAFE_GENERATION` | Bộ lọc an toàn (mặt người nổi tiếng, bạo lực, trẻ em) | Đổi góc máy (lưng/nghiêng), bỏ tên thật, làm mềm từ ngữ; nhờ Claude sửa prompt |
| Video kẹt **PROCESSING** quá lâu | Mạng / Flow chậm / job treo | `/fk-doctor` hoặc `/fk-status` — đừng bấm tạo lại hàng loạt |
| Ảnh nhân vật mỗi cảnh một mặt | Quên ảnh mẫu hoặc mô tả lại ngoại hình trong cảnh | Làm xong `/fk-gen-refs` trước; cảnh chỉ viết hành động |
| Link ảnh/video không mở được | Link Google hết hạn | `/fk-refresh-urls` |
| Windows báo lệnh không chạy | Đang gõ trong CMD, hoặc `curl` là alias của PowerShell | Dùng **PowerShell** (`.\setup.ps1`, `Invoke-RestMethod`) — không dùng CMD. WSL/Git Bash vẫn được |

**Đừng** tự viết script vòng lặp tạo 40 cảnh. Trợ lý đã có cách gửi hàng loạt an toàn; tự spam dễ bị Google chặn (`UNUSUAL_ACTIVITY`). Nếu bị chặn: dừng gửi → xoá cookie `google.com` và `labs.google` trong cài đặt Chrome → login lại Flow → gửi chậm hơn.

> **Lưu ý về Extension:** Extension của Flow Kit hoạt động **hoàn toàn thụ động (Passive Mode)** — không tự động bấm (`click`) hay cuộn trang (`scrollTop`) làm phiền bạn. Khi bạn bấm mở/xem clip trên tab Google Flow, extension sẽ tự động bắt các liên kết video đã ký hợp lệ để tải và ghép video.

---

## 11. Giới hạn cần biết

- Mỗi clip gốc khoảng **8 giây**. Phim 2 phút ≈ 15 cảnh, không phải 1 lần bấm.
- Ảnh mẫu **trước**, ảnh cảnh **sau**, video **cuối**. Làm ngược sẽ lỗi hoặc lệch mặt.
- Sửa ảnh một cảnh sẽ **xoá** video / 4K của cảnh đó — phải tạo lại phía sau.
- Upscale 4K cần tài khoản Flow hạng cao hơn.
- Credit trừ trên **Google Flow**, không trừ trong Flow Kit.
- Máy phải **mở** và agent **chạy** suốt lúc đang tạo. Đóng laptop giữa chừng thì việc đang làm có thể hỏng.
- Flow Kit chạy **trên máy bạn**, không phải website công cộng. Người khác trên mạng không vào được `127.0.0.1`.

---

## 12. Thuật ngữ

| Chữ bạn sẽ gặp | Nghĩa thường |
|----------------|--------------|
| **Dự án / project** | Một câu chuyện (nhiều nhân vật, một hoặc vài video) |
| **Video** | Một tập / một đoạn phim trong dự án |
| **Cảnh / scene** | Một nhịp khoảng 8 giây |
| **Entity / nhân vật tham chiếu** | Người, nơi, đồ cần trông giống nhau nhiều cảnh |
| **Ảnh mẫu / reference / ref** | Ảnh “chuẩn mặt” gửi kèm mỗi lần vẽ |
| **material** | Phong cách hình (Pixar, anime, hiện thực…) |
| **Agent** | Phần mềm Python chạy nền (`python -m agent.main`) |
| **Extension** | Mảnh gắn vào Chrome, nói chuyện với Google Flow |
| **Claude Code** | Cửa sổ chat điều khiển Flow Kit (một trong các lựa chọn) |
| **Antigravity** | IDE/agent của Google — xem [phần 15](#15-dùng-google-antigravity-20) |
| **OpenCode** | Agent mã nguồn mở — xem [phần 16](#16-dùng-opencode) |
| **Skill / lệnh `/fk-…`** | Công thức có sẵn (“tạo ảnh mẫu”, “ghép phim”…) |
| **Pipeline** | Cả dây chuyền từ ý tưởng tới file cuối |
| **ROOT / CONTINUATION** | Cảnh mở đầu chuỗi / cảnh nối tiếp cùng không gian |
| **Ngang / dọc** | 16:9 (YouTube dài) / 9:16 (Shorts) |
| **media_id** | Mã ảnh/video trên Google — bạn không cần nhớ |
| **DeepSeek Flash / Qwen Plus** | Hai model thay Claude khi không mua subscription — xem [phần 13](#13-không-mua-claude-deepseek-flash--qwen-37-plus) |

---

## 13. Không mua Claude: DeepSeek Flash + Qwen 3.7 Plus

Đây là **phương án mặc định** khi bạn muốn dùng Claude Code (cửa sổ chat + lệnh `/fk-…`) mà **không trả phí Claude.ai**.

Hai model làm việc **khác nhau**. Đừng gộp cả hai vào một cửa sổ rồi hy vọng chúng tự chia.

| Model | Vai trò | Dùng khi |
|-------|---------|----------|
| **Qwen 3.7 Plus** | Não — suy luận, viết, xem ảnh | Research, tạo dự án, viết/sửa prompt, review clip, `/fk-doctor` |
| **DeepSeek V4 Flash** (bản 0731, tên API `deepseek-v4-flash`) | Tay — nhanh, rẻ, làm đúng recipe | `/fk-gen-refs`, `/fk-gen-images`, `/fk-gen-videos`, poll, `/fk-status`, `/fk-concat` |

**Một vòng làm phim điển hình**

1. Mở cửa sổ **Plus** → nghiên cứu (nếu cần) → `/fk-create-project` → chỉnh lookbook / lời cảnh.
2. Mở cửa sổ **Flash** → `/fk-gen-refs` rồi images / videos (để cửa sổ chạy, đi uống nước).
3. Quay lại **Plus** → `/fk-review-video` → sửa cảnh kém.
4. Cửa sổ **Flash** → `/fk-concat`.

### Bạn cần thêm gì

- Tài khoản + API key [DeepSeek](https://platform.deepseek.com/api_keys)
- Tài khoản + API key **Qwen 3.7 Plus** — thường qua [Alibaba Cloud Model Studio / DashScope](https://www.alibabacloud.com/help/en/model-studio/) hoặc cổng trung gian kiểu OpenRouter (slug thường là `qwen/qwen3.7-plus`). Nhà cung cấp phải nói **Anthropic Messages API** (`/v1/messages`), không chỉ “giống ChatGPT”.
- Claude Code đã cài (như [phần 4.6](#46-cài-claude-code-nếu-chưa-có))

Flow Kit (`python -m agent.main` + Chrome + Google Flow) **không đổi**. Chỉ đổi “bộ não” trong cửa sổ chat.

### Cửa sổ Flash (DeepSeek)

Trong Terminal, **trước** khi gõ `claude`:

```bash
export ANTHROPIC_BASE_URL=https://api.deepseek.com/anthropic
export ANTHROPIC_AUTH_TOKEN="dán-key-deepseek-vào-đây"
export ANTHROPIC_MODEL=deepseek-v4-flash
export ANTHROPIC_DEFAULT_HAIKU_MODEL=deepseek-v4-flash
export ANTHROPIC_SMALL_FAST_MODEL=deepseek-v4-flash
export CLAUDE_CODE_SUBAGENT_MODEL=deepseek-v4-flash
```

Rồi vào thư mục Flow Kit và chạy `claude`.

Trong chat gõ `/status`: phải thấy **Anthropic base URL** trỏ `api.deepseek.com`, không còn login Claude.ai.

### Cửa sổ Plus (Qwen)

Mở **Terminal khác** (để cửa sổ Flash chạy song song nếu đang gen). Thay URL và tên model đúng như nhà cung cấp Plus ghi (ví dụ OpenRouter):

```bash
export ANTHROPIC_BASE_URL="https://openrouter.ai/api"
export ANTHROPIC_AUTH_TOKEN="dán-key-openrouter-hoặc-dashscope-vào-đây"
export ANTHROPIC_MODEL="qwen/qwen3.7-plus"
```

Nếu dùng DashScope / endpoint riêng của Alibaba, hỏi họ **base URL Anthropic** và **đúng tên model** — đừng đoán. Sai tên model thì request lỗi hoặc bị map nhầm.

Rồi `claude` trong thư mục Flow Kit. `/status` phải hiện URL của Qwen/cổng, không phải DeepSeek.

### Ghi nhớ để khỏi lẫn

- **Hai cửa sổ Terminal = hai bộ biến môi trường.** Cửa sổ không “nhớ” model của cửa sổ kia.
- Flash **không** nên viết kịch bản hay research một mình — dễ nhảy bước, bịa sự kiện, tự viết script vòng lặp (cấm trong Flow Kit).
- Plus **đừng** dùng để poll hàng chục cảnh — chậm và đắt hơn Flash.
- Review clip: dùng **Plus** (nhìn được ảnh). Flash gần như không làm được bước này.
- Chất lượng: đủ làm kênh đều đặn nếu bạn **xem ảnh mẫu** trước khi quay video. Không ngang gói Claude đắt tiền ở bước “đạo diễn” và fact-check khó.
- Key để trong máy bạn (`~/.bashrc` hoặc chỉ export trong phiên). **Không** dán key vào file trong Git.

Muốn nhớ cấu hình mỗi ngày, thêm hai hàm vào `~/.bashrc` (sửa key cho đúng):

```bash
fk-flash() {
  export ANTHROPIC_BASE_URL=https://api.deepseek.com/anthropic
  export ANTHROPIC_AUTH_TOKEN="KEY_DEEPSEEK"
  export ANTHROPIC_MODEL=deepseek-v4-flash
  export ANTHROPIC_DEFAULT_HAIKU_MODEL=deepseek-v4-flash
  export ANTHROPIC_SMALL_FAST_MODEL=deepseek-v4-flash
  export CLAUDE_CODE_SUBAGENT_MODEL=deepseek-v4-flash
  cd /đường/dẫn/tới/flowkit && claude "$@"
}

fk-plus() {
  export ANTHROPIC_BASE_URL="https://openrouter.ai/api"
  export ANTHROPIC_AUTH_TOKEN="KEY_QWEN_HOAC_OPENROUTER"
  export ANTHROPIC_MODEL="qwen/qwen3.7-plus"
  cd /đường/dẫn/tới/flowkit && claude "$@"
}
```

Sau đó mỗi ngày: một cửa sổ `fk-plus`, một cửa sổ `fk-flash` (agent + Chrome Flow vẫn phải mở như [phần 5](#5-mỗi-ngày-mở-máy-làm-việc)).

---

## 14. Video kiểu Vox / motion graphic (rẻ, phù hợp UAT)

Không sinh clip AI từng cảnh. Máy lấy **ảnh cảnh** + Ken Burns (phóng/kéo chậm) + TTS/chữ/nhạc như cũ.

1. Khi tạo project, thêm `"render_mode": "motion"` (mặc định là `cinematic` = video AI).

   Hoặc sửa project có sẵn:

   ```bash
   curl -s -X PATCH http://127.0.0.1:8100/api/projects/<PID> \
     -H "Content-Type: application/json" \
     -d '{"render_mode":"motion"}'
   ```

2. Làm ảnh mẫu + ảnh cảnh như bình thường (`/fk-gen-refs`, `/fk-gen-images`).
3. Gõ `/fk-gen-videos` hoặc `/fk-render-motion` — server **không** gọi Veo/Flow video. File nằm ở `output/<slug>/motion/`.
4. (Tuỳ) `/fk-gen-narrator` rồi `/fk-concat-fit-narrator`.

Bước này gần như chỉ tốn **ảnh** + CPU máy bạn. Không upscale, không chain video AI. Cảnh CONTINUATION vẫn crossfade lúc ghép.

---

## 15. Dùng Google Antigravity 2.0

Antigravity là trợ lý AI của Google (cửa sổ chat trong IDE). **Máy bếp Flow Kit không đổi**: Chrome + extension + `python -m agent.main` vẫn phải mở như [phần 5](#5-mỗi-ngày-mở-máy-làm-việc). Chỉ đổi cửa sổ chat.

### Lần đầu

1. Cài [Antigravity](https://antigravity.google/) và đăng nhập tài khoản Google.
2. Mở **đúng thư mục Flow Kit** (thư mục có file `setup.py`).
3. Trong Terminal (đứng trong thư mục đó) gõ:

```
python setup.py --tool antigravity
```

Lệnh này tạo các “công thức” `/fk-…` cho Antigravity. Làm **một lần** (hoặc mỗi khi Flow Kit thêm lệnh mới).

4. Trong Antigravity, mở lại thư mục dự án (hoặc bắt đầu chat mới) để nó thấy các lệnh vừa tạo.
5. Mở panel **Rules** (menu `…` trên khung Agent) → rule `flowkit` → đặt **Always On**. Đây là các luật bắt buộc (UUID, không viết script vòng lặp, dùng batch API).

### Làm việc hàng ngày

Giống Claude Code: gõ `/` rồi chọn `/fk-create-project`, `/fk-gen-refs`, … hoặc nói tiếng Việt.

Antigravity còn **tự chọn** công thức phù hợp khi bạn mô tả việc — không bắt buộc gõ `/`. Nếu nó làm lệch pipeline, nhắc rõ: “dùng skill fk-gen-refs”.

Video kiểu Vox: [phần 14](#14-video-kiểu-vox--motion-graphic-rẻ-phù-hợp-uat) — `/fk-render-motion` cũng có trên Antigravity sau khi chạy `setup.py`.

### Việc không cần làm

- Không cần Claude Code nếu bạn chỉ dùng Antigravity.
- Không cần [phần 13](#13-không-mua-claude-deepseek-flash--qwen-37-plus) — phần đó chỉ cho Claude Code trỏ sang model khác.
- Không đổi Google Flow, extension, hay cổng 8100.

### Nếu gõ `/` không thấy lệnh `fk-`

- Đã chạy `python setup.py --tool antigravity` trong **đúng** thư mục Flow Kit chưa?
- Đã mở đúng thư mục đó trong Antigravity chưa (không phải thư mục cha)?
- Thử chat mới, hoặc gõ tên skill: “chạy fk-status”.

---

## 16. Dùng OpenCode

OpenCode là trợ lý AI mã nguồn mở (cửa sổ chat trong terminal hoặc IDE). **Máy bếp Flow Kit không đổi**: Chrome + extension + `python -m agent.main` vẫn phải mở như [phần 5](#5-mỗi-ngày-mở-máy-làm-việc). Chỉ đổi cửa sổ chat.

### Lần đầu

1. Cài [OpenCode](https://opencode.ai/) và chọn model (Claude, GPT, Gemini, hoặc model local — tuỳ bạn).
2. Mở **đúng thư mục Flow Kit** (thư mục có file `setup.py`).
3. Trong Terminal (đứng trong thư mục đó) gõ:

```
python setup.py --tool opencode
```

Lệnh này tạo các “công thức” `/fk-…` và skill cho OpenCode. Làm **một lần** (hoặc mỗi khi Flow Kit thêm lệnh mới).

4. Trong thư mục Flow Kit gõ `opencode` (hoặc mở project trong app OpenCode), rồi bắt đầu chat mới.

### Làm việc hàng ngày

Giống Claude Code: gõ `/` rồi chọn `/fk-create-project`, `/fk-gen-refs`, … hoặc nói tiếng Việt.

OpenCode còn **tự nạp skill** khi bạn mô tả việc (tool `skill`). Nếu nó làm lệch pipeline, nhắc rõ: “dùng skill fk-gen-refs”.

Video kiểu Vox: [phần 14](#14-video-kiểu-vox--motion-graphic-rẻ-phù-hợp-uat) — `/fk-render-motion` cũng có trên OpenCode sau khi chạy `setup.py`.

### Việc không cần làm

- Không cần Claude Code nếu bạn chỉ dùng OpenCode.
- Không cần [phần 13](#13-không-mua-claude-deepseek-flash--qwen-37-plus) trừ khi bạn vẫn mở Claude Code.
- Không đổi Google Flow, extension, hay cổng 8100.

### Nếu gõ `/` không thấy lệnh `fk-`

- Đã chạy `python setup.py --tool opencode` trong **đúng** thư mục Flow Kit chưa?
- Đã mở đúng thư mục đó trong OpenCode chưa?
- Thử chat mới, hoặc nói: “chạy skill fk-status”.

---

## Tiếp theo

1. Làm xong [phần 4](#4-cài-đặt-lần-đầu) và [phần 5](#5-mỗi-ngày-mở-máy-làm-việc) đến khi `health` báo `extension_connected: true`
2. Chọn cửa sổ chat: Claude Code ([phần 4.6](#46-cài-claude-code-nếu-chưa-có), không mua gói thì [phần 13](#13-không-mua-claude-deepseek-flash--qwen-37-plus)), Antigravity ([phần 15](#15-dùng-google-antigravity-20)), hoặc OpenCode ([phần 16](#16-dùng-opencode))
3. Mô tả một chuyện **3 cảnh**, phong cách rõ
4. Xem ảnh mẫu trước khi cho phép làm video
5. Khi đỏ đèn: `/fk-doctor`, đừng đoán

Chúc bạn ra clip đầu tiên trơn tru.
