-- The users table, as the API expects to find it.
--
-- This is a reconstruction from the columns the code reads, not an export
-- of the live table: MySQL on this machine would not hand over its schema
-- (root has a password that is not the XAMPP default). Prefer exporting
-- your real table from phpMyAdmin -- Export, SQL, "Add DROP TABLE" off --
-- and importing that, so the accounts come with it. Use this file only to
-- create the table from scratch.
--
-- Columns the API actually touches: id, username, password, email,
-- first_name, last_name, is_admin. Anything else in your table is carried
-- along harmlessly; huni_public_user() reads by name and ignores the rest.

CREATE TABLE IF NOT EXISTS `users` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `username` VARCHAR(100) NOT NULL,
  -- bcrypt output is 60 characters, but 255 leaves room to change
  -- algorithm later without a migration. Never a plain password.
  `password` VARCHAR(255) NOT NULL,
  `email` VARCHAR(255) NOT NULL,
  `first_name` VARCHAR(100) DEFAULT NULL,
  `last_name` VARCHAR(100) DEFAULT NULL,
  -- Admin rights live here and only here. The app asks to sign in as
  -- admin and the server decides; the client is never trusted with it.
  `is_admin` TINYINT(1) NOT NULL DEFAULT 0,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  -- The register endpoint checks for clashes before inserting, but these
  -- make a race between two simultaneous registrations impossible rather
  -- than unlikely.
  UNIQUE KEY `username` (`username`),
  UNIQUE KEY `email` (`email`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Granting admin rights, after registering the account through the app:
--   UPDATE users SET is_admin = 1 WHERE username = 'your_admin_username';
