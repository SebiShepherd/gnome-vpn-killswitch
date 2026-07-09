# gnome-vpn-killswitch

A native GNOME Quick Settings toggle for a strict VPN kill switch, independent of
the VPN connection toggle itself.

## Why

GNOME/NetworkManager has no built-in kill switch. Commercial VPN clients (Surfshark,
NordVPN, ...) ship one inside their own app, hidden behind a proprietary GUI. This
project exposes the same behavior as a plain GNOME Shell Quick Settings toggle, backed
by a static nftables rule set — no polling, no event-race, no vendor lock-in.

## Design

- **Backend**: an nftables table that, while loaded, allows traffic only via the
  VPN interface (+ loopback + established/related). No dispatcher hook, no polling —
  the rule is either loaded or not, so if the VPN interface goes down for *any* reason
  while the kill switch is on, traffic is blocked automatically as a side effect of the
  rule itself.
- **Privilege boundary**: a small root helper script (`backend/killswitch.sh`) loads/
  unloads the nftables table. A Polkit policy authorizes the toggle without a password
  prompt on every click.
- **Frontend**: a GNOME Shell extension adding a "Kill Switch" toggle to the Quick
  Settings VPN menu, calling the helper via `pkexec`.

Behavior is strict-only for v1: VPN toggle and Kill Switch toggle are independent —
to get unprotected internet you must turn both off. See project history / issues for
a possible "soft" mode (only block on unintended drops) — not natively detectable
without the extension itself owning the disconnect action.

## Status

Early scaffold. Not yet functional end to end.

## Prior art

[0xtf/VPN-Killswitch](https://github.com/0xtf/VPN-Killswitch) — dispatcher-based,
iptables, CLI-only, tied to a specific VPN profile, no GUI toggle. Different
mechanism (event-triggered vs. static rule), no code reused.

## License

MIT
