-- ============================================================================
-- HỆ THỐNG QUẢN LÝ LỚP 5/4 - NĂM HỌC 2026-2027
-- GVCN: PHAN THỊ DIỄM TRANG
-- Cơ sở dữ liệu: Supabase (PostgreSQL + Auth + RLS + Storage)
-- LƯU Ý: Không chứa dữ liệu mẫu (Mock Data). Chạy toàn bộ trong Supabase SQL Editor.
-- ============================================================================

-- 1. Kích hoạt Extension tạo UUID
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- 2. Bảng PROFILES (Lưu thông tin người dùng & Phân quyền: admin, teacher, student)
CREATE TABLE IF NOT EXISTS public.profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT UNIQUE NOT NULL,
  full_name TEXT NOT NULL,
  role TEXT NOT NULL DEFAULT 'student' CHECK (role IN ('admin', 'teacher', 'student')),
  student_code TEXT,
  phone TEXT,
  avatar_url TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 3. Các hàm kiểm tra phân quyền (Security Definer tránh đệ quy RLS)
CREATE OR REPLACE FUNCTION public.get_my_role()
RETURNS TEXT
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
  SELECT COALESCE(
    (SELECT role FROM public.profiles WHERE id = auth.uid()),
    'student'
  );
$$;

CREATE OR REPLACE FUNCTION public.is_staff()
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid() AND role IN ('admin', 'teacher')
  );
$$;

CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid() AND role = 'admin'
  );
$$;

-- 4. Trigger tự động tạo Profile khi người dùng Đăng ký qua Supabase Auth
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_role TEXT;
  v_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO v_count FROM public.profiles;
  v_role := COALESCE(NEW.raw_user_meta_data->>'role', 'student');
  IF v_role NOT IN ('admin', 'teacher', 'student') THEN
    v_role := 'student';
  END IF;
  -- Nếu là tài khoản đầu tiên trong hệ thống và chưa chọn quyền, mặc định là admin
  IF v_count = 0 AND (NEW.raw_user_meta_data->>'role') IS NULL THEN
    v_role := 'admin';
  END IF;

  INSERT INTO public.profiles (id, email, full_name, role, student_code, phone)
  VALUES (
    NEW.id,
    COALESCE(NEW.email, ''),
    COALESCE(NEW.raw_user_meta_data->>'full_name', split_part(COALESCE(NEW.email, 'Học sinh'), '@', 1)),
    v_role,
    NULLIF(NEW.raw_user_meta_data->>'student_code', ''),
    NULLIF(NEW.raw_user_meta_data->>'phone', '')
  )
  ON CONFLICT (id) DO UPDATE SET
    email = EXCLUDED.email,
    full_name = EXCLUDED.full_name,
    updated_at = NOW();

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- 5. Bảng STUDENTS (Danh sách học sinh Lớp 5/4)
CREATE TABLE IF NOT EXISTS public.students (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  student_code TEXT UNIQUE NOT NULL,
  full_name TEXT NOT NULL,
  gender TEXT NOT NULL DEFAULT 'Nam' CHECK (gender IN ('Nam', 'Nữ', 'Khác')),
  date_of_birth DATE,
  group_number INTEGER NOT NULL DEFAULT 1 CHECK (group_number BETWEEN 1 AND 4),
  position TEXT NOT NULL DEFAULT 'Thành viên',
  parent_name TEXT,
  parent_phone TEXT,
  address TEXT,
  status TEXT NOT NULL DEFAULT 'Đang học' CHECK (status IN ('Đang học', 'Chuyển trường', 'Bảo lưu')),
  notes TEXT,
  created_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 6. Bảng ANNOUNCEMENTS (Sổ Dặn dò & Thông báo Lớp 5/4)
CREATE TABLE IF NOT EXISTS public.announcements (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  content TEXT NOT NULL,
  category TEXT NOT NULL DEFAULT 'Học tập' CHECK (category IN ('Học tập', 'Sinh hoạt lớp', 'Phong trào', 'Phụ huynh', 'Kiểm tra')),
  priority TEXT NOT NULL DEFAULT 'Bình thường' CHECK (priority IN ('Bình thường', 'Quan trọng', 'Khẩn cấp')),
  week_number INTEGER CHECK (week_number BETWEEN 1 AND 40),
  due_date DATE,
  is_pinned BOOLEAN NOT NULL DEFAULT FALSE,
  author_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  author_name TEXT NOT NULL DEFAULT 'GVCN Phan Thị Diễm Trang',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 7. Bảng ANNOUNCEMENT_READS (Theo dõi học sinh/phụ huynh đã xác nhận đọc dặn dò)
CREATE TABLE IF NOT EXISTS public.announcement_reads (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  announcement_id UUID NOT NULL REFERENCES public.announcements(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  user_name TEXT NOT NULL,
  read_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(announcement_id, user_id)
);

-- 8. Bảng ACADEMIC_WEEKS (Quản lý các Tuần học thi đua Năm học 2026-2027)
CREATE TABLE IF NOT EXISTS public.academic_weeks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  week_number INTEGER UNIQUE NOT NULL CHECK (week_number BETWEEN 1 AND 40),
  title TEXT NOT NULL,
  start_date DATE,
  end_date DATE,
  base_points INTEGER NOT NULL DEFAULT 100,
  status TEXT NOT NULL DEFAULT 'Đang diễn ra' CHECK (status IN ('Đang diễn ra', 'Đã tổng kết')),
  summary_note TEXT,
  created_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 9. Bảng COMPETITION_RECORDS (Chấm điểm Thi đua theo Tuần / Tổ / Cá nhân)
CREATE TABLE IF NOT EXISTS public.competition_records (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  week_id UUID NOT NULL REFERENCES public.academic_weeks(id) ON DELETE CASCADE,
  week_number INTEGER NOT NULL,
  target_type TEXT NOT NULL DEFAULT 'student' CHECK (target_type IN ('student', 'group')),
  student_id UUID REFERENCES public.students(id) ON DELETE CASCADE,
  student_name TEXT,
  group_number INTEGER NOT NULL CHECK (group_number BETWEEN 1 AND 4),
  category TEXT NOT NULL DEFAULT 'Học tập' CHECK (category IN ('Chuyên cần', 'Học tập', 'Kỷ luật', 'Vệ sinh', 'Phong trào', 'Tuyên dương')),
  points_delta INTEGER NOT NULL,
  reason TEXT NOT NULL,
  recorded_date DATE NOT NULL DEFAULT CURRENT_DATE,
  recorded_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  recorded_by_name TEXT NOT NULL DEFAULT 'GVCN Phan Thị Diễm Trang',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 10. Bảng ACTIVITY_ALBUMS (Album sự kiện & hoạt động ngoại khóa)
CREATE TABLE IF NOT EXISTS public.activity_albums (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  description TEXT,
  event_date DATE NOT NULL DEFAULT CURRENT_DATE,
  week_number INTEGER,
  cover_url TEXT,
  created_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 11. Bảng ACTIVITY_PHOTOS (Hình ảnh học sinh tham gia hoạt động)
CREATE TABLE IF NOT EXISTS public.activity_photos (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  album_id UUID REFERENCES public.activity_albums(id) ON DELETE CASCADE,
  album_title TEXT,
  title TEXT NOT NULL,
  caption TEXT,
  image_url TEXT NOT NULL,
  storage_path TEXT,
  activity_date DATE NOT NULL DEFAULT CURRENT_DATE,
  uploaded_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  uploaded_by_name TEXT NOT NULL DEFAULT 'GVCN Phan Thị Diễm Trang',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 12. Tạo Indexes tối ưu truy vấn
CREATE INDEX IF NOT EXISTS idx_students_group ON public.students(group_number);
CREATE INDEX IF NOT EXISTS idx_students_code ON public.students(student_code);
CREATE INDEX IF NOT EXISTS idx_announcements_pinned ON public.announcements(is_pinned DESC, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_competition_week ON public.competition_records(week_id);
CREATE INDEX IF NOT EXISTS idx_competition_group ON public.competition_records(group_number);
CREATE INDEX IF NOT EXISTS idx_photos_album ON public.activity_photos(album_id);

-- 13. Bật Row Level Security (RLS) trên toàn bộ các bảng
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.students ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.announcements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.announcement_reads ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.academic_weeks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.competition_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.activity_albums ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.activity_photos ENABLE ROW LEVEL SECURITY;

-- 14. Chính sách bảo mật RLS cho bảng PROFILES
DROP POLICY IF EXISTS "profiles_select_all" ON public.profiles;
CREATE POLICY "profiles_select_all" ON public.profiles
  FOR SELECT USING (true);

DROP POLICY IF EXISTS "profiles_insert_own" ON public.profiles;
CREATE POLICY "profiles_insert_own" ON public.profiles
  FOR INSERT WITH CHECK (auth.uid() = id);

DROP POLICY IF EXISTS "profiles_update_own_or_admin" ON public.profiles;
CREATE POLICY "profiles_update_own_or_admin" ON public.profiles
  FOR UPDATE USING (auth.uid() = id OR public.is_admin())
  WITH CHECK (auth.uid() = id OR public.is_admin());

DROP POLICY IF EXISTS "profiles_delete_admin" ON public.profiles;
CREATE POLICY "profiles_delete_admin" ON public.profiles
  FOR DELETE USING (public.is_admin());

-- 15. Chính sách bảo mật RLS cho bảng STUDENTS (Chỉ Admin & Giáo viên được thêm/sửa/xóa)
DROP POLICY IF EXISTS "students_select_all" ON public.students;
CREATE POLICY "students_select_all" ON public.students
  FOR SELECT USING (true);

DROP POLICY IF EXISTS "students_insert_staff" ON public.students;
CREATE POLICY "students_insert_staff" ON public.students
  FOR INSERT WITH CHECK (public.is_staff());

DROP POLICY IF EXISTS "students_update_staff" ON public.students;
CREATE POLICY "students_update_staff" ON public.students
  FOR UPDATE USING (public.is_staff()) WITH CHECK (public.is_staff());

DROP POLICY IF EXISTS "students_delete_staff" ON public.students;
CREATE POLICY "students_delete_staff" ON public.students
  FOR DELETE USING (public.is_staff());

-- 16. Chính sách bảo mật RLS cho bảng ANNOUNCEMENTS (Chỉ Admin & Giáo viên đăng/sửa/xóa)
DROP POLICY IF EXISTS "announcements_select_all" ON public.announcements;
CREATE POLICY "announcements_select_all" ON public.announcements
  FOR SELECT USING (true);

DROP POLICY IF EXISTS "announcements_insert_staff" ON public.announcements;
CREATE POLICY "announcements_insert_staff" ON public.announcements
  FOR INSERT WITH CHECK (public.is_staff());

DROP POLICY IF EXISTS "announcements_update_staff" ON public.announcements;
CREATE POLICY "announcements_update_staff" ON public.announcements
  FOR UPDATE USING (public.is_staff()) WITH CHECK (public.is_staff());

DROP POLICY IF EXISTS "announcements_delete_staff" ON public.announcements;
CREATE POLICY "announcements_delete_staff" ON public.announcements
  FOR DELETE USING (public.is_staff());

-- 17. Chính sách bảo mật RLS cho bảng ANNOUNCEMENT_READS (Học sinh xác nhận đã đọc)
DROP POLICY IF EXISTS "announcement_reads_select_all" ON public.announcement_reads;
CREATE POLICY "announcement_reads_select_all" ON public.announcement_reads
  FOR SELECT USING (true);

DROP POLICY IF EXISTS "announcement_reads_insert_auth" ON public.announcement_reads;
CREATE POLICY "announcement_reads_insert_auth" ON public.announcement_reads
  FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "announcement_reads_delete_own_or_staff" ON public.announcement_reads;
CREATE POLICY "announcement_reads_delete_own_or_staff" ON public.announcement_reads
  FOR DELETE USING (auth.uid() = user_id OR public.is_staff());

-- 18. Chính sách bảo mật RLS cho bảng ACADEMIC_WEEKS & COMPETITION_RECORDS
DROP POLICY IF EXISTS "weeks_select_all" ON public.academic_weeks;
CREATE POLICY "weeks_select_all" ON public.academic_weeks
  FOR SELECT USING (true);

DROP POLICY IF EXISTS "weeks_write_staff" ON public.academic_weeks;
CREATE POLICY "weeks_write_staff" ON public.academic_weeks
  FOR ALL USING (public.is_staff()) WITH CHECK (public.is_staff());

DROP POLICY IF EXISTS "competition_select_all" ON public.competition_records;
CREATE POLICY "competition_select_all" ON public.competition_records
  FOR SELECT USING (true);

DROP POLICY IF EXISTS "competition_write_staff" ON public.competition_records;
CREATE POLICY "competition_write_staff" ON public.competition_records
  FOR ALL USING (public.is_staff()) WITH CHECK (public.is_staff());

-- 19. Chính sách bảo mật RLS cho bảng ACTIVITY_ALBUMS & ACTIVITY_PHOTOS
DROP POLICY IF EXISTS "albums_select_all" ON public.activity_albums;
CREATE POLICY "albums_select_all" ON public.activity_albums
  FOR SELECT USING (true);

DROP POLICY IF EXISTS "albums_write_staff" ON public.activity_albums;
CREATE POLICY "albums_write_staff" ON public.activity_albums
  FOR ALL USING (public.is_staff()) WITH CHECK (public.is_staff());

DROP POLICY IF EXISTS "photos_select_all" ON public.activity_photos;
CREATE POLICY "photos_select_all" ON public.activity_photos
  FOR SELECT USING (true);

DROP POLICY IF EXISTS "photos_insert_authenticated" ON public.activity_photos;
CREATE POLICY "photos_insert_authenticated" ON public.activity_photos
  FOR INSERT WITH CHECK (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "photos_modify_owner_or_staff" ON public.activity_photos;
CREATE POLICY "photos_modify_owner_or_staff" ON public.activity_photos
  FOR UPDATE USING (uploaded_by = auth.uid() OR public.is_staff());

DROP POLICY IF EXISTS "photos_delete_owner_or_staff" ON public.activity_photos;
CREATE POLICY "photos_delete_owner_or_staff" ON public.activity_photos
  FOR DELETE USING (uploaded_by = auth.uid() OR public.is_staff());

-- 20. Khởi tạo Supabase Storage Bucket 'class-media' để lưu trữ Hình ảnh hoạt động
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'class-media',
  'class-media',
  true,
  10485760,
  ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/gif']
)
ON CONFLICT (id) DO UPDATE SET
  public = true,
  file_size_limit = 10485760,
  allowed_mime_types = ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/gif'];

DROP POLICY IF EXISTS "class_media_public_read" ON storage.objects;
CREATE POLICY "class_media_public_read" ON storage.objects
  FOR SELECT USING (bucket_id = 'class-media');

DROP POLICY IF EXISTS "class_media_auth_upload" ON storage.objects;
CREATE POLICY "class_media_auth_upload" ON storage.objects
  FOR INSERT WITH CHECK (bucket_id = 'class-media' AND auth.role() = 'authenticated');

DROP POLICY IF EXISTS "class_media_staff_delete" ON storage.objects;
CREATE POLICY "class_media_staff_delete" ON storage.objects
  FOR DELETE USING (bucket_id = 'class-media' AND (owner = auth.uid() OR public.is_staff()));
