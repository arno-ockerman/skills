# Test Data Seed Template for Staging

```sql
-- ════════════════════════════════════════════════════════════════════════════════
-- Club App — Test Data Seed for Staging
-- Run AFTER all migrations on clean staging database
-- Provides: 3 clubs, members, sessions, credits, loyalty, rewards, packages
-- ════════════════════════════════════════════════════════════════════════════════

-- Helpers
\set club_crossfit = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::uuid
\set club_yoga       = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'::uuid
\set club_hyrox      = 'cccccccc-cccc-cccc-cccc-cccccccccccc'::uuid

\set owner_1     = 'user_owner_crossfit'
\set owner_2     = 'user_owner_yoga'
\set owner_3     = 'user_owner_hyrox'
\set staff_1     = 'user_staff_crossfit_1'
\set staff_2     = 'user_staff_yoga_1'
\set client_1    = 'user_client_1'
\set client_2    = 'user_client_2'
\set client_3    = 'user_client_3'
\set client_4    = 'user_client_4'
\set client_5    = 'user_client_5'

-- 1. CLUBS
INSERT INTO clubs (id, name, slug, sport_type, description, address, onboarding_completed, onboarding_completed_at)
VALUES
  (:club_crossfit, 'CrossFit Brakel', 'crossfit-brakel', 'CrossFit', 'High-intensity functional training box', 'Dorp 15, 9660 Brakel', true, now() - interval '6 months'),
  (:club_yoga, 'Yoga Studio Brakel', 'yoga-brakel', 'Yoga', 'Peaceful yoga studio', 'Kerkstraat 42, 9660 Brakel', true, now() - interval '4 months'),
  (:club_hyrox, 'Hyrox Training Center', 'hyrox-brakel', 'Hyrox', 'Official Hyrox affiliate', 'Industrieweg 8, 9660 Brakel', true, now() - interval '2 months')
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name,
  slug = EXCLUDED.slug,
  sport_type = EXCLUDED.sport_type,
  description = EXCLUDED.description,
  address = EXCLUDED.address;

-- 2. CLUB MEMBERS (owners, staff, clients)
INSERT INTO club_members (id, club_id, user_id, role, status, assigned_coach_member_id, created_at)
VALUES
  (gen_random_uuid(), :club_crossfit, :owner_1, 'owner', 'active', NULL, now() - interval '6 months'),
  (gen_random_uuid(), :club_crossfit, :staff_1, 'staff', 'active', NULL, now() - interval '5 months')
ON CONFLICT (club_id, user_id) DO NOTHING;

INSERT INTO club_members (id, club_id, user_id, role, status, assigned_coach_member_id, created_at)
VALUES
  (gen_random_uuid(), :club_yoga, :owner_2, 'owner', 'active', NULL, now() - interval '4 months'),
  (gen_random_uuid(), :club_yoga, :staff_2, 'staff', 'active', NULL, now() - interval '3 months')
ON CONFLICT (club_id, user_id) DO NOTHING;

INSERT INTO club_members (id, club_id, user_id, role, status, created_at)
VALUES
  (gen_random_uuid(), :club_hyrox, :owner_3, 'owner', 'active', now() - interval '2 months')
ON CONFLICT (club_id, user_id) DO NOTHING;

-- Clients with coach assignments
WITH crossfit_staff AS (SELECT id FROM club_members WHERE club_id = :club_crossfit AND role = 'staff' LIMIT 1),
     yoga_staff   AS (SELECT id FROM club_members WHERE club_id = :club_yoga AND role = 'staff' LIMIT 1)
INSERT INTO club_members (id, club_id, user_id, role, status, assigned_coach_member_id, created_at)
SELECT gen_random_uuid(), :club_crossfit, :client_1, 'client', 'active', id, now() - interval '3 months' FROM crossfit_staff
UNION ALL
SELECT gen_random_uuid(), :club_crossfit, :client_2, 'client', 'active', id, now() - interval '2 months' FROM crossfit_staff
UNION ALL
SELECT gen_random_uuid(), :club_yoga, :client_3, 'client', 'active', id, now() - interval '3 months' FROM yoga_staff
UNION ALL
SELECT gen_random_uuid(), :club_yoga, :client_4, 'client', 'active', id, now() - interval '1 month' FROM yoga_staff
UNION ALL
SELECT gen_random_uuid(), :club_hyrox, :client_5, 'client', 'active', NULL, now() - interval '2 weeks'
ON CONFLICT (club_id, user_id) DO NOTHING;

-- 3. CLASS TYPES
INSERT INTO class_types (id, club_id, name, duration_minutes, max_participants, color)
VALUES
  (gen_random_uuid(), :club_crossfit, 'WOD', 60, 20, '#FF6B35'),
  (gen_random_uuid(), :club_crossfit, 'Strength', 45, 15, '#C0392B'),
  (gen_random_uuid(), :club_crossfit, 'Gymnastics', 60, 12, '#E74C3C'),
  (gen_random_uuid(), :club_yoga, 'Vinyasa Flow', 75, 25, '#27AE60'),
  (gen_random_uuid(), :club_yoga, 'Yin Yoga', 60, 20, '#2ECC71'),
  (gen_random_uuid(), :club_yoga, 'Hot Yoga', 90, 15, '#E67E22'),
  (gen_random_uuid(), :club_hyrox, 'Hyrox Prep', 90, 16, '#8E44AD'),
  (gen_random_uuid(), :club_hyrox, 'Engine Builder', 60, 20, '#9B59B6')
ON CONFLICT DO NOTHING;

-- 4. PRICING PLANS
INSERT INTO pricing_plans (id, club_id, name, type, price_cents, credits, is_active)
VALUES
  (gen_random_uuid(), :club_crossfit, 'Unlimited Monthly', 'unlimited', 14900, NULL, true),
  (gen_random_uuid(), :club_crossfit, '10-Credit Pack', 'credits', 12000, 10, true),
  (gen_random_uuid(), :club_crossfit, '20-Credit Pack', 'credits', 22000, 20, true),
  (gen_random_uuid(), :club_yoga, 'Unlimited Monthly', 'unlimited', 12900, NULL, true),
  (gen_random_uuid(), :club_yoga, '8-Credit Pack', 'credits', 9600, 8, true),
  (gen_random_uuid(), :club_yoga, '16-Credit Pack', 'credits', 17600, 16, true),
  (gen_random_uuid(), :club_hyrox, 'Hyrox Unlimited', 'unlimited', 17900, NULL, true),
  (gen_random_uuid(), :club_hyrox, 'Hyrox 10-Pack', 'credits', 15000, 10, true)
ON CONFLICT DO NOTHING;

-- 5. OPERATING HOURS
INSERT INTO operating_hours (club_id, day_of_week, is_open, open_time, close_time)
SELECT :club_crossfit, d, true, '06:00', '22:00' FROM generate_series(0, 6) d
UNION ALL
SELECT :club_yoga, d, true, '07:00', '21:00' FROM generate_series(0, 6) d
UNION ALL
SELECT :club_hyrox, d, true, '06:00', '22:00' FROM generate_series(0, 6) d
ON CONFLICT (club_id, day_of_week) DO UPDATE SET
  is_open = EXCLUDED.is_open,
  open_time = EXCLUDED.open_time,
  close_time = EXCLUDED.close_time;

-- 6. WORKOUT SESSIONS (14 days)
WITH ct_crossfit_wod AS (SELECT id FROM class_types WHERE club_id = :club_crossfit AND name = 'WOD' LIMIT 1),
     ct_crossfit_str AS (SELECT id FROM class_types WHERE club_id = :club_crossfit AND name = 'Strength' LIMIT 1),
     ct_crossfit_gym AS (SELECT id FROM class_types WHERE club_id = :club_crossfit AND name = 'Gymnastics' LIMIT 1),
     ct_yoga_vin  AS (SELECT id FROM class_types WHERE club_id = :club_yoga AND name = 'Vinyasa Flow' LIMIT 1),
     ct_yoga_yin  AS (SELECT id FROM class_types WHERE club_id = :club_yoga AND name = 'Yin Yoga' LIMIT 1),
     ct_yoga_hot  AS (SELECT id FROM class_types WHERE club_id = :club_yoga AND name = 'Hot Yoga' LIMIT 1),
     ct_hyrox_hyr AS (SELECT id FROM class_types WHERE club_id = :club_hyrox AND name = 'Hyrox Prep' LIMIT 1),
     ct_hyrox_eng AS (SELECT id FROM class_types WHERE club_id = :club_hyrox AND name = 'Engine Builder' LIMIT 1),
     staff_cf AS (SELECT id FROM club_members WHERE club_id = :club_crossfit AND role = 'staff' LIMIT 1),
     staff_yg AS (SELECT id FROM club_members WHERE club_id = :club_yoga AND role = 'staff' LIMIT 1),
     staff_hx AS (SELECT id FROM club_members WHERE club_id = :club_hyrox AND role = 'staff' LIMIT 1)
INSERT INTO workout_sessions (
  id, club_id, class_type_id, title, name, description,
  session_date, start_time, end_time, location, coach_name, coach_id,
  spots_total, spots_booked, waitlist_enabled, waitlist_count,
  credits_cost, status, created_at
)
SELECT gen_random_uuid(), :club_crossfit, id, 'Morning WOD', 'WOD', 'High-intensity workout',
  CURRENT_DATE + (n || ' days')::interval, '06:00', '07:00', 'Main Floor', 'Coach Mike', id,
  20, 0, true, 0, 1, 'scheduled', now()
FROM ct_crossfit_wod, generate_series(0, 13) n, staff_cf
UNION ALL
SELECT gen_random_uuid(), :club_crossfit, id, 'Evening Strength', 'Strength', 'Barbell strength',
  CURRENT_DATE + (n || ' days')::interval, '18:00', '18:45', 'Weight Room', 'Coach Mike', id,
  15, 0, true, 0, 1, 'scheduled', now()
FROM ct_crossfit_str, generate_series(0, 13, 2) n, staff_cf
UNION ALL
SELECT gen_random_uuid(), :club_yoga, id, 'Sunrise Vinyasa', 'Vinyasa Flow', 'Energizing flow',
  CURRENT_DATE + (n || ' days')::interval, '07:00', '08:15', 'Studio A', 'Coach Sarah', id,
  25, 0, true, 0, 1, 'scheduled', now()
FROM ct_yoga_vin, generate_series(0, 13) n, staff_yg
UNION ALL
SELECT gen_random_uuid(), :club_yoga, id, 'Evening Yin', 'Yin Yoga', 'Deep stretch',
  CURRENT_DATE + (n || ' days')::interval, '19:00', '20:00', 'Studio B', 'Coach Sarah', id,
  20, 0, true, 0, 1, 'scheduled', now()
FROM ct_yoga_yin, generate_series(0, 13, 2) n, staff_yg
UNION ALL
SELECT gen_random_uuid(), :club_hyrox, id, 'Hyrox Simulation', 'Hyrox Prep', 'Full simulation',
  CURRENT_DATE + (n || ' days')::interval, '09:00', '10:30', 'Main Track', 'Coach Alex', id,
  16, 0, true, 0, 2, 'scheduled', now()
FROM ct_hyrox_hyr, generate_series(0, 13, 3) n, staff_hx
UNION ALL
SELECT gen_random_uuid(), :club_hyrox, id, 'Engine Builder', 'Engine Builder', 'Running + ski erg',
  CURRENT_DATE + (n || ' days')::interval, '18:30', '19:30', 'Cardio Zone', 'Coach Alex', id,
  20, 0, true, 0, 1, 'scheduled', now()
FROM ct_hyrox_eng, generate_series(0, 13, 2) n, staff_hx
ON CONFLICT DO NOTHING;

-- 7. CREDIT PACKAGES (for Mollie purchases)
WITH billing_owner_cf AS (SELECT id FROM club_members WHERE club_id = :club_crossfit AND role = 'owner' LIMIT 1),
     billing_owner_yg AS (SELECT id FROM club_members WHERE club_id = :club_yoga AND role = 'owner' LIMIT 1),
     billing_owner_hx AS (SELECT id FROM club_members WHERE club_id = :club_hyrox AND role = 'owner' LIMIT 1)
INSERT INTO credit_packages (id, club_id, name, description, credits, bonus_credits, price_eur, payout_recipient, is_active, created_at)
SELECT gen_random_uuid(), :club_crossfit, 'Starter 5', '5 credits for new members', 5, 0, 49.00, 'owner', true, now() FROM billing_owner_cf
UNION ALL
SELECT gen_random_uuid(), :club_crossfit, 'Regular 10', '10 credits + 1 bonus', 10, 1, 89.00, 'owner', true, now() FROM billing_owner_cf
UNION ALL
SELECT gen_random_uuid(), :club_crossfit, 'Pro 20', '20 credits + 3 bonus', 20, 3, 159.00, 'owner', true, now() FROM billing_owner_cf
UNION ALL
SELECT gen_random_uuid(), :club_yoga, 'Yoga Starter 4', '4 yoga sessions', 4, 0, 39.00, 'owner', true, now() FROM billing_owner_yg
UNION ALL
SELECT gen_random_uuid(), :club_yoga, 'Yoga Regular 8', '8 sessions + 1 bonus', 8, 1, 69.00, 'owner', true, now() FROM billing_owner_yg
UNION ALL
SELECT gen_random_uuid(), :club_hyrox, 'Hyrox Pack 5', '5 Hyrox sessions', 5, 0, 79.00, 'owner', true, now() FROM billing_owner_hx
UNION ALL
SELECT gen_random_uuid(), :club_hyrox, 'Hyrox Pack 10', '10 sessions + 2 bonus', 10, 2, 139.00, 'owner', true, now() FROM billing_owner_hx
ON CONFLICT DO NOTHING;

-- 8. WALLETS & INITIAL CREDITS (10 credits each client)
INSERT INTO wallets (club_id, user_id, balance, total_earned, total_spent)
SELECT cm.club_id, cm.user_id, 10, 10, 0
FROM club_members cm
WHERE cm.role = 'client'
ON CONFLICT (club_id, user_id) DO UPDATE SET
  balance = 10,
  total_earned = 10,
  total_spent = 0;

INSERT INTO credit_transactions (club_id, user_id, amount, type, description)
SELECT cm.club_id, cm.user_id, 10, 'admin_grant', 'Welcome credits'
FROM club_members cm
WHERE cm.role = 'client'
ON CONFLICT DO NOTHING;

-- 9. LOYALTY PROGRAMS
INSERT INTO loyalty_programs (id, club_id, name, description, points_per_session, points_per_credit, tiers_json, is_active)
VALUES
  (gen_random_uuid(), :club_crossfit, 'CrossFit Loyalty', 'Earn points for every session', 15, 2,
   '[{"name": "Bronze", "min_points": 0, "color": "#CD7F32"}, {"name": "Silver", "min_points": 300, "color": "#C0C0C0"}, {"name": "Gold", "min_points": 1000, "color": "#FFD700"}, {"name": "Platinum", "min_points": 2500, "color": "#E5E4E2"}]'::jsonb, true),
  (gen_random_uuid(), :club_yoga, 'Yoga Rewards', 'Collect points for your practice', 10, 1,
   '[{"name": "Seeker", "min_points": 0, "color": "#8FBC8F"}, {"name": "Practitioner", "min_points": 200, "color": "#98FB98"}, {"name": "Master", "min_points": 800, "color": "#32CD32"}, {"name": "Guru", "min_points": 2000, "color": "#228B22"}]'::jsonb, true),
  (gen_random_uuid(), :club_hyrox, 'Hyrox Champions', 'Points for Hyrox training', 20, 3,
   '[{"name": "Rookie", "min_points": 0, "color": "#B8860B"}, {"name": "Contender", "min_points": 500, "color": "#DAA520"}, {"name": "Elite", "min_points": 1500, "color": "#FFD700"}, {"name": "Champion", "min_points": 3000, "color": "#FFA500"}]'::jsonb, true)
ON CONFLICT DO NOTHING;

INSERT INTO user_loyalty (user_id, club_id, total_points, current_points, tier, sessions_completed)
SELECT cm.user_id, cm.club_id, 0, 0, 'Bronze', 0
FROM club_members cm
JOIN loyalty_programs lp ON lp.club_id = cm.club_id
WHERE cm.role = 'client'
ON CONFLICT (user_id, club_id) DO NOTHING;

-- 10. REWARDS
INSERT INTO rewards (id, club_id, name, description, type, points_cost, available_count, required_tier, is_active)
VALUES
  (gen_random_uuid(), :club_crossfit, 'Free Protein Shake', 'Post-workout shake', 'merchandise', 150, 50, 'Bronze', true),
  (gen_random_uuid(), :club_crossfit, 'Box T-Shirt', 'Official tee', 'merchandise', 500, 20, 'Silver', true),
  (gen_random_uuid(), :club_crossfit, '10% Off Next Pack', 'Discount on package', 'discount', 300, 100, 'Bronze', true),
  (gen_random_uuid(), :club_yoga, 'Free Mat Rental', 'Use studio mat', 'merchandise', 80, 100, 'Seeker', true),
  (gen_random_uuid(), :club_yoga, 'Yoga Block Set', 'Cork blocks', 'merchandise', 400, 15, 'Practitioner', true),
  (gen_random_uuid(), :club_hyrox, 'Hyrox Socks', 'Training socks', 'merchandise', 200, 30, 'Rookie', true),
  (gen_random_uuid(), :club_hyrox, 'Sled Push Session', 'Private 30-min coaching', 'experience', 1000, 5, 'Contender', true)
ON CONFLICT DO NOTHING;

-- 11. MEMBER PAYOUT ACCOUNTS
INSERT INTO member_payout_accounts (id, club_id, club_member_id, provider, status, mollie_organization_id, mollie_account_id)
SELECT gen_random_uuid(), :club_crossfit, id, 'mollie', 'active', 'org_test_crossfit', 'acc_test_crossfit'
FROM club_members WHERE club_id = :club_crossfit AND role = 'staff' LIMIT 1
UNION ALL
SELECT gen_random_uuid(), :club_yoga, id, 'mollie', 'active', 'org_test_yoga', 'acc_test_yoga'
FROM club_members WHERE club_id = :club_yoga AND role = 'staff' LIMIT 1
ON CONFLICT (club_member_id, provider) DO NOTHING;

-- 12. QR SECRET (run manually in SQL Editor)
-- INSERT INTO vault.secrets (name, secret) VALUES ('qr_secret', gen_random_bytes(32))
-- ON CONFLICT (name) DO NOTHING;

-- ════════════════════════════════════════════════════════════════════════════════
-- VERIFICATION QUERIES
-- ════════════════════════════════════════════════════════════════════════════════
-- SELECT c.name, COUNT(cm.id) as members FROM clubs c LEFT JOIN club_members cm ON cm.club_id = c.id GROUP BY c.id, c.name;
-- SELECT club_id, user_id, balance FROM wallets WHERE balance > 0;
-- SELECT club_id, COUNT(*) as sessions FROM workout_sessions WHERE status = 'scheduled' GROUP BY club_id;
-- SELECT * FROM credit_packages WHERE is_active = true;
-- SELECT * FROM loyalty_programs WHERE is_active = true;
```