-- Añadir campo username a profiles
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS username text;

-- Crear username automáticamente a partir del email para perfiles existentes
UPDATE public.profiles 
SET username = LOWER(SPLIT_PART(email, '@', 1))
WHERE username IS NULL;

-- Index para búsqueda rápida
CREATE UNIQUE INDEX IF NOT EXISTS profiles_username_idx ON public.profiles(username) WHERE username IS NOT NULL;

-- Permitir a anónimos buscar coaches por username al registrarse
CREATE POLICY IF NOT EXISTS "Buscar coach por username al registrarse"
  ON profiles FOR SELECT
  TO anon
  USING (role = 'coach');

-- El trigger ya crea el perfil, pero ahora también asigna username
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS trigger LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public AS $$
BEGIN
  INSERT INTO public.profiles (id, email, full_name, role, username)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'full_name', SPLIT_PART(NEW.email,'@',1)),
    COALESCE(NEW.raw_user_meta_data->>'role','client'),
    LOWER(SPLIT_PART(NEW.email,'@',1))
  )
  ON CONFLICT (id) DO UPDATE SET
    username = COALESCE(profiles.username, LOWER(SPLIT_PART(NEW.email,'@',1)));
  RETURN NEW;
END; $$;
