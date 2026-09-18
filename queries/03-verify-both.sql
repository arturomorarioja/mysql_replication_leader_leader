USE multi_leader_messages;

-- Run on both nodes after performing both inserts.
SELECT *
FROM messages
ORDER BY id;
