import os
import unittest
from unittest.mock import patch

from services.pos_jwt_route_adapter import _resolve_client_ip


class TestPosJwtRouteAdapter(unittest.TestCase):
    def test_untrusted_peer_cannot_spoof_forwarded_ip(self):
        with patch.dict(os.environ, {"POS_TRUSTED_PROXY_IPS": ""}, clear=False):
            self.assertEqual(
                _resolve_client_ip("198.51.100.10", "203.0.113.55"),
                "198.51.100.10",
            )

    def test_trusted_proxy_can_forward_valid_ip(self):
        with patch.dict(
            os.environ,
            {"POS_TRUSTED_PROXY_IPS": "10.0.0.5"},
            clear=False,
        ):
            self.assertEqual(
                _resolve_client_ip("10.0.0.5", "203.0.113.55, 10.0.0.5"),
                "203.0.113.55",
            )

    def test_invalid_forwarded_ip_falls_back_to_peer(self):
        with patch.dict(
            os.environ,
            {"POS_TRUSTED_PROXY_IPS": "10.0.0.5"},
            clear=False,
        ):
            self.assertEqual(
                _resolve_client_ip("10.0.0.5", "not-an-ip"),
                "10.0.0.5",
            )


if __name__ == "__main__":
    unittest.main()
