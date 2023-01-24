# cdr_store

## Initial setup

### MariaDB in rancher
```bash
docker pull mariadb
# set custom port to avoid clash with local mysql
docker run --name mariadb -p 127.0.0.1:3307:3306 -e MYSQL_ROOT_PASSWORD=password mariadb &

docker run -it --link mariadb:mysql --rm mariadb sh -c 'exec mysql -h"$MYSQL_PORT_3306_TCP_ADDR" -P"$MYSQL_PORT_3306_TCP_PORT" -uroot -p"$MYSQL_ENV_MYSQL_ROOT_PASSWORD"'
CREATE DATABASE cdr_store;
CREATE USER 'cdr_store_admin'@'172.17.0.1' IDENTIFIED BY 'cdr_store_pass';
GRANT ALL ON cdr_store.* TO 'cdr_store_admin'@'172.17.0.1' IDENTIFIED BY 'cdr_store_pass' WITH GRANT OPTION;
FLUSH PRIVILEGES;
EXIT;
```

### Perl prerequisities
```bash
brew install openssl mysql-connector-c
sudo cpan install DBD::MariaDB
```
