# cdr_store

## API Documentation
#### [Online ReDoc documentation](https://redocly.github.io/redoc/?url=https://raw.githubusercontent.com/david-dot-krupicka/cdr_store/develop/spec/swagger.yaml)
#### [Local ReDoc documentation](index.html)

## Setup

### MariaDB in rancher
<i>Note: PostgreSQL would be better choice, probably much faster</i>
```bash
docker pull mariadb
# set custom port to avoid clash with local mysql
docker run --name mariadb -p 127.0.0.1:3307:3306 -e MYSQL_ROOT_PASSWORD=password mariadb &

docker run -it --link mariadb:mysql --rm mariadb sh -c 'exec mysql -h"$MYSQL_PORT_3306_TCP_ADDR" -P"$MYSQL_PORT_3306_TCP_PORT" -uroot -p"$MYSQL_ENV_MYSQL_ROOT_PASSWORD"'
CREATE DATABASE cdr_store;
CREATE USER 'cdr_store_admin'@'172.17.0.1' IDENTIFIED BY 'cdr_store_pass';
GRANT ALL ON cdr_store.* TO 'cdr_store_admin'@'172.17.0.1' IDENTIFIED BY 'cdr_store_pass' WITH GRANT OPTION;
CREATE DATABASE test;
CREATE USER 'cdr_store_test'@'172.17.0.1' IDENTIFIED BY 'cdr_store_test_pass';
GRANT ALL ON test.* TO 'cdr_store_test'@'172.17.0.1' IDENTIFIED BY 'cdr_store_test_pass' WITH GRANT OPTION;
FLUSH PRIVILEGES;
EXIT;
```

### Perl prerequisities
```bash
brew install openssl mysql-connector-c
cpan install DBD::MariaDB
cpan install Exception::Class::Try::Catch
cpan install Function::Parameters
cpan install Mojo::mysql
cpan install Mojolicious::Plugin::OpenAPI
cpan install Moose
cpan install MooseX::NonMoose
cpan install Text::CSV_XS
cpan install Time::Piece
```

### DB Schema
See [this link](#db_schema), current schema version is 3.

Created or updated with `bin/cdrstore.pl deploy`

For the sake of the example, let's create simple tables which will just
demonstrate a possible DB model, following a simple rule - if there are
repeated records, store them in related table.

## Run
In application HOME:
1. Deploy the empty database (with MariaDB running in the container)

    `bin/cdr_store.pl deploy`

   (see `bin/cdr_store.pl deploy --help`)
2. Upload the data either with

   `bin/cdr_store.pl upload example_cdr.csv`

    Or via web form in http://127.0.0.1:3000/api/upload

3. Play with API, see the ReDoc documentation.

    The endpoins are:
    * api/get_cdr
    * api/count_cdr
    * api/cdr_by_caller

## Testing
`prove -I./lib -v` in applications home.

<i>Note: Tests depend on running 02_commands.t first, this test loads the data</i>
    
## What could be done better
1. Use OpenAPI v3 specification (oneOf/allOf would be handy)
2. Do not abuse upload command to load the data (I was glad I managed to have it working)
   
    There is also no progress bar or at least spinning wheel in the web form
3. Probably the error handling - at first I tried with Exception::Class::Try::Catch,
   not knowing how Mojo handles the exceptions internally
4. Maybe do not use Moose at all
5. Tests should be independent, not relying on each other
6. Add POD
7. Setup database with Dockerfile or docker-compose

## The biggest gotchas
1. Error handling surprise!
2. The upload
