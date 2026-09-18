USE multi_leader_messages;

-- Verify that this tab is connected to Node A.
-- server_id should be 1; Node A uses odd AUTO_INCREMENT values.
SELECT
    @@hostname AS server,
    @@server_id AS server_id,
    @@auto_increment_increment AS auto_increment_increment,
    @@auto_increment_offset AS auto_increment_offset;

INSERT INTO messages (source_node, content)
VALUES ('A', 'Inserted on node A');

SELECT *
FROM messages
ORDER BY id;

SHOW REPLICA STATUS;

SELECT @@GLOBAL.gtid_executed AS gtid_executed;
