# Official PostgreSQL image + our first-start setup scripts.
FROM postgres:16

# Every .sql/.sh file in init/ runs once, when the warehouse volume is empty.
COPY init/ /docker-entrypoint-initdb.d/
