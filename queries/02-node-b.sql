USE multi_leader_messages;

-- Verify that this tab is connected to Node B.
-- server_id should be 2; Node B uses even AUTO_INCREMENT values.
SELECT
    @@hostname AS server,
    @@server_id AS server_id,
    @@auto_increment_increment AS auto_increment_increment,
    @@auto_increment_offset AS auto_increment_offset;

-- First verify that the row inserted on Node A has arrived.
SELECT *
FROM messages
ORDER BY id;

INSERT INTO messages (source_node, content)
VALUES ('B', 'Inserted on node B');

SELECT *
FROM messages
ORDER BY id;

SHOW REPLICA STATUS;

SELECT @@GLOBAL.gtid_executed AS gtid_executed;
