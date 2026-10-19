CREATE OR REPLACE FUNCTION public.qn_shares_store_with(p_user uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT public.qn_caller_id() IS NOT NULL AND (p_user = public.qn_caller_id() OR EXISTS (
    SELECT 1 FROM public.store_members a JOIN public.store_members b ON a.store_id = b.store_id
    WHERE a.user_id = public.qn_caller_id() AND b.user_id = p_user));
$$;
DROP FUNCTION IF EXISTS public.get_store_staff_directory_v4(uuid);
