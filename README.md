# godaddy-api
Scripts for manipulate dns-records over API GoDaddy

Проверено на Ubuntu 16.04. По идее должно работать на большинстве дистрибутивов Linux.

Описание работы набора скриптов смотреть на wiki   
https://github.com/kern-panic/godaddy-api/wiki

Во всех скриптах необходимо указать путь к файлу .env в котором должны
быть указаны реквизиты для аутентификации и авторизации (Key:Secret) в
сервисе API GoDaddy.

Например:

$ cat /path/to/.env   
KEY='9jL...j7A'   
SECRET='Ppq...Eov'   

