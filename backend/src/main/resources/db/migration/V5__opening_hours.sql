-- =============================================================================
-- V5: Set default operating hours to 00:00-23:59 to support 24/7 access
-- =============================================================================
UPDATE system_config
SET value = jsonb_set(
    value,
    '{openingHours}',
    '[{"dayOfWeek": 1, "opensAt": "00:00", "closesAt": "23:59"}, {"dayOfWeek": 2, "opensAt": "00:00", "closesAt": "23:59"}, {"dayOfWeek": 3, "opensAt": "00:00", "closesAt": "23:59"}, {"dayOfWeek": 4, "opensAt": "00:00", "closesAt": "23:59"}, {"dayOfWeek": 5, "opensAt": "00:00", "closesAt": "23:59"}, {"dayOfWeek": 6, "opensAt": "00:00", "closesAt": "23:59"}, {"dayOfWeek": 7, "opensAt": "00:00", "closesAt": "23:59"}]'::jsonb
)
WHERE key = 'operational';
