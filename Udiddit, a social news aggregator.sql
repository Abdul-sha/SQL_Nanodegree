CREATE TABLE "users" (
  "id"               serial PRIMARY KEY,
  "username"         varchar(25) UNIQUE NOT NULL,
  CONSTRAINT "username_lenght" CHECK (length(trim("username")) > 0),
  "login_timestamp"  timestamp
);

CREATE INDEX "users_not_logged_in_last_year" ON "users" ("username", "login_timestamp");

CREATE TABLE "topics" (
  "id"          serial PRIMARY KEY,
  "topic_name"  varchar(30) UNIQUE NOT NULL,
  "describtion" varchar(500),
  "user_id"     integer REFERENCES "users",
  CONSTRAINT "topic_name_not_zero" CHECK (length(trim("topic_name")) > 0)
);

CREATE INDEX "find_user_ids_in_topics" ON "topics" ("user_id");

CREATE TABLE "posts" (
  "id"            serial PRIMARY KEY,
  "post_title"    varchar(500) UNIQUE NOT NULL,
  "url"           text,
  "text_content"  text,
  "user_id"       integer REFERENCES "users" ON DELETE SET NULL,
  "topic_id"      integer NOT NULL REFERENCES "topics" ON DELETE CASCADE,
  CONSTRAINT "posts_title_not_zero" CHECK (length(trim("post_title")) > 0),
  CONSTRAINT "check_text_or_URL_isexist." CHECK (
    (("url") IS NULL AND ("text_content") IS NOT NULL) OR
    (("url") IS NOT NULL AND ("text_content") IS NULL)
  ),
  "post_timestamp" timestamp
);

CREATE INDEX "find_user_ids_in_posts" ON "posts" ("user_id");
CREATE INDEX "find_posts_URL" ON "posts" ("url");
CREATE INDEX "find_topic_ids_in_post" ON "posts" ("topic_id");
CREATE INDEX "find_posts_with_timestamp_and_topic" ON "posts" ("url", "text_content", "topic_id", "post_timestamp");
CREATE INDEX "find_posts_with_timestamp_and_user" ON "posts" ("url", "text_content", "user_id", "post_timestamp");

CREATE TABLE "comments" (
  "id"                 serial PRIMARY KEY,
  "comment_text"       text NOT NULL,
  "user_id"            integer REFERENCES "users" ON DELETE SET NULL,
  "post_id"            integer NOT NULL REFERENCES "posts" ON DELETE CASCADE,
  "parent_comment_id"  integer DEFAULT NULL REFERENCES "comments" ON DELETE CASCADE,
  CONSTRAINT "check_posts_length_not_zero" CHECK (Length(Trim("comment_text")) > 0)
);

CREATE INDEX "find_top_level_comments_for_a_post" ON "comments" ("comment_text", "post_id", "parent_comment_id") WHERE "parent_comment_id" = NULL;
CREATE INDEX "find_all_the_direct_children_a_parent_comment" ON "comments" ("comment_text", "parent_comment_id");
CREATE INDEX "find_latest_comments_by_user" ON "comments" ("comment_text", "user_id");

CREATE TABLE "post_votes" (
  "id"        SERIAL PRIMARY KEY,
  "post_vote" INTEGER NOT NULL,
  "user_id"   INTEGER REFERENCES "users" ON DELETE SET NULL,
  "post_id"   INTEGER NOT NULL REFERENCES "posts" ON DELETE CASCADE,
  CONSTRAINT "set_values_for_votes" CHECK ("post_vote" = 1 OR "post_vote" = -1),
  CONSTRAINT "uniq_user_vote_per_post" UNIQUE ("id", "user_id", "post_id")
);

CREATE INDEX "find_score_of_post" ON "post_votes" ("post_vote", "post_id");


---------------------Migrate the data to the new schema created------------------------

Insert Into "users" ("username")
Select
    "username"
From
    "bad_posts"
Union
Select
    "username"
From
    "bad_comments"
Union
SELECT
     DISTINCT regexp_split_to_table(upvotes, ',')
FROM
    bad_posts
UNION
SELECT
     DISTINCT regexp_split_to_table(downvotes, ',')
FROM
    bad_posts;


INSERT INTO "topics"
  ("topic_name")
SELECT DISTINCT topic
FROM "bad_posts";

INSERT INTO "posts"
  ("post_title",
   "url",
   "text_content",
   "user_id",
   "topic_id")
  SELECT P.title,
        P.url,
        P.text_content,
        u.id AS user_id,
        t.id AS topic_id
  FROM "bad_posts" P
    join "users"  u
      ON p.username = u.username
    join "topics" t
      ON p.topic = t.topic_name;


Insert into "comments" (
  "user_id", "post_id", "comment_text"
)
Select
  "u"."id",
  "p"."id",
  "bc"."text_content"
From
  bad_comments bc
Join users u On "u"."username" = "bc"."username"
Join "posts" p On "p"."id" = "bc"."post_id";



INSERT INTO "post_votes"
  ("post_vote",
   "user_id",
   "post_id")
WITH "bad_posts_upvotes" AS (
  SELECT title,
         Regexp_split_to_table(bp.upvotes, ',') AS username_upvotes
  FROM "bad_posts" bp
),
"bad_posts_downvotes" AS (
  SELECT title,
         Regexp_split_to_table(bp.downvotes, ',') AS username_downvotes
  FROM "bad_posts" bp
)
SELECT 1 AS post_vote,
       u.id AS voter_user_id,
       po.id AS post_id
FROM "bad_posts_upvotes" bpu
JOIN "posts" po
  ON bpu.title = po.post_title
JOIN "users" u
  ON bpu.username_upvotes = u.username
UNION ALL
SELECT -1 AS post_vote,
       u.id AS voter_user_id,
       po.id AS post_id
FROM "bad_posts_downvotes" bpd
JOIN "posts" po
  ON bpd.title = po.post_title
JOIN "users" u
  ON bpd.username_downvotes = u.username;