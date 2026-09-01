"""Static regressions only. These do NOT replace the real PostgreSQL gate."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]


class PosWalletContractTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        sql = (ROOT / 'supabase/migrations/20260902_atomic_settlement_v5.sql').read_text()
        cls.rpc = sql.split('CREATE OR REPLACE FUNCTION public.complete_pos_sale_v1(', 1)[1]
        cls.client = (ROOT / 'lib/modules/pos/screens/checkout_sheet.dart').read_text()

    def test_replay_precedes_wallet_mutation(self):
        self.assertLess(self.rpc.index("'is_replay', true"), self.rpc.index('SET real_balance'))
        self.assertIn("'wallet_real_used', v_existing_op.wallet_real_used", self.rpc)
        self.assertIn("'wallet_bonus_used', v_existing_op.wallet_bonus_used", self.rpc)

    def test_customer_locked_and_scoped_before_wallet_write(self):
        self.assertIn('WHERE id = p_customer_id AND store_id = p_store_id AND is_deleted = false\n    FOR UPDATE', self.rpc)
        self.assertLess(self.rpc.index('FOR UPDATE'), self.rpc.index('SET real_balance'))
        self.assertIn('INSERT INTO public.balance_transactions', self.rpc)

    def test_insufficient_wallet_before_order_writes(self):
        self.assertLess(self.rpc.index("'INSUFFICIENT_WALLET'"), self.rpc.index('INSERT INTO public.orders'))
        self.assertIn("THEN 'wallet'", self.rpc)

    def test_expected_total_checked_before_mutation(self):
        self.assertLess(self.rpc.index('p_expected_total <> v_total_amount'), self.rpc.index('INSERT INTO public.orders'))

    def test_client_never_debits_wallet_after_commit(self):
        self.assertNotIn('.spendWallet(', self.client)
        self.assertNotIn('total: cartSnapshot.total', self.client)
        self.assertIn('total: saleResult.totalAmount', self.client)
        self.assertIn('!saleResult.isReplay', self.client)


if __name__ == '__main__':
    unittest.main()
