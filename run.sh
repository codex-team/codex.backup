cd /home/backup
mysqldump -u $USERNAME -p$PASSWORD $DATABASE > backup.sql
php backup.php backup.sql .sql mysql_

echo -e "auth $REDISPASSWORD\nsave" | redis-cli
cp /usr/bin/redis/dump.rdb dump.rdb
php backup.php dump.rdb .rdb redis_

tar zcvf backup.tar.gz /var/www/ifmo.su/upload
php backup.php backup.tar.gz .tar.gz upload_