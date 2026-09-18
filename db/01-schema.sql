DROP DATABASE IF EXISTS multi_leader_messages;
CREATE DATABASE multi_leader_messages;
USE multi_leader_messages;

CREATE TABLE messages (
    id INT PRIMARY KEY AUTO_INCREMENT,
    source_node VARCHAR(10) NOT NULL,
    content VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
