DROP TRIGGER IF EXISTS kti_fill_free_note_v1 ON public.kitchen_ticket_items;
DROP TRIGGER IF EXISTS bsi_sync_note_to_ticket_v1 ON public.ban_session_items;
DROP FUNCTION IF EXISTS public.kti_fill_free_note_v1();
DROP FUNCTION IF EXISTS public.bsi_sync_note_to_ticket_v1();
