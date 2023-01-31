# cdr_store

## Initial setup

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
cpan install Mojo::mysql
cpan install Mojolicious::Plugin::OpenAPI
cpan install Function::Parameters
cpan install Text::CSV_XS
cpan install Exception::Class::Try::Catch
cpan install Moose MooseX::NonMoose
cpan install Date::Simple
```

### DB Schema
  .... create a link here

Created or updated with `bin/cdrstore.pl deploy`

For the sake of the example, let's create simple tables which will just
demonstrate a possible DB model, following a simple rule - if there are
repeated records, store them in related table.

## Testing
`prove -I./lib -v t/basic.t` in applications home.