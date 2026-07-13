# SweetTime Roadmap

## MVP

- Single-chain mobile app with configurable brand data.
- FastAPI API-first backend.
- React Admin web panel.
- Mock/cash/QR demo payments.
- Loyalty defaults: `1 point = 1 KGS`, earn `5%`, spend up to `30%`, expires after 12 months.
- Referral defaults: invited user receives 50 points, inviter receives 100 points after invited user's first completed order.
- Demo recurring order module for "daily drink" subscriptions.

## Next Production Steps

- Replace mock OTP provider with SMS, WhatsApp or Telegram provider.
- Add merchant integrations for MBank QR, Элсом, О!Деньги and cards.
- Add fiscal receipt provider.
- Add hosted privacy policy, support URL and account deletion web link.
- Add Yandex Delivery after API access and commercial terms are confirmed.
- Add audit logs, exports and advanced analytics.

## White-label Path

- Keep `company_id` across models and API.
- Move brand colors, menu content, legal links and payment providers to company settings.
- Add company switcher and tenant-scoped admin permissions.
- Add billing/subscription module for SaaS packaging.
