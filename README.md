# Website Lớp 5/4 – Năm học 2026-2027 (GVCN: Phan Thị Diễm Trang)

## 1. Khởi tạo Cơ sở dữ liệu trên Supabase
1. Đăng nhập [Supabase](https://supabase.com/) và tạo Project mới.
2. Vào mục **SQL Editor** -> **New Query**, dán toàn bộ nội dung file `supabase/schema.sql` và nhấn **Run**.
3. Vào **Project Settings** -> **API** để lấy `Project URL` và `anon public key`.
4. (Khuyến nghị) Trong **Authentication** -> **Providers** -> **Email**, bạn có thể tắt mục *Confirm email* nếu muốn học sinh đăng ký xong đăng nhập được ngay không cần xác nhận qua hộp thư.

## 2. Chạy thử dưới máy cá nhân (Local)
```bash
npm install
cp .env.example .env
# Điền VITE_SUPABASE_URL và VITE_SUPABASE_ANON_KEY vào file .env
npm run dev
```

## 3. Deploy lên Vercel
1. Đẩy thư mục dự án này lên GitHub / GitLab.
2. Đăng nhập [Vercel](https://vercel.com/) -> **Add New Project** -> Chọn kho mã nguồn vừa tải lên.
3. Tại mục **Environment Variables**, thêm 2 biến:
   - `VITE_SUPABASE_URL`: URL dự án Supabase của bạn
   - `VITE_SUPABASE_ANON_KEY`: Khóa anon public key của bạn
4. Bấm **Deploy**.
