CREATE DATABASE IF NOT EXISTS helloRetail;
USE helloRetail;
CREATE TABLE IF NOT EXISTS creditCards(rowkey VARCHAR(255) PRIMARY KEY, rowvalue VARCHAR(255) NOT NULL);
DELETE FROM creditCards;
INSERT INTO creditCards(rowkey, rowvalue) VALUES ("alice", "1234-5678-9123-4567");
