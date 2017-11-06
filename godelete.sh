#!/bin/bash
#
# Данная программа предназначена для удаления DNS-записей типа A, CNAME, NS, MX, TXT
# для доменов, управляемых через аккаунт на сервисе GoDaddy.
# Программа работает только в интерактивном режиме.
# Для запуска программы необходимо просто набрать её имя в командной строке
# без аргументов.
#

### SET VARIABLES ####################################################################

# Секретная пара для аутентификации на GoDaddy
source /path/to/.env
AUTH="Authorization: sso-key ${KEY}:${SECRET}"

# Установка места хранения резервных копий
BACKUP_DIR='/var/backups/godaddy'

# Установим директорию и файл для временного хранения данных DNS-zone
TMP_DIR='/tmp'
TMP_FILE='godaddy.tmp.file'

### SET FUNCTIONS ####################################################################

# Функция для динамического получения списка dns-доменов, имеющих статус "ACTIVE"
get_domains(){
  curl -s -X GET -H "${AUTH}" https://api.godaddy.com/v1/domains/ | sed 's/}/}\n/g' | sed 's/^,//' | grep -i active | cut -f 2 -d , | cut -f 2 -d : | sed 's/"//g'
}

# Функция для получения файла описания DNS-zone для выбранного домена
golist(){
  curl -s -X GET -H "${AUTH}" https://api.godaddy.com/v1/domains/$(dns_domains)/records | sed 's/}/}\n/g' | sed 's/\[/\[\n/g'
}

# Функция подготовки записей DNS-records для выборки
select_str(){
  cat ${TMP_DIR}/${TMP_FILE}.$(dns_domains) | sed '/TXT/ d' | sed '/^\[/ d' | sed '/^\]/ d' | sed 's/^.*type/"type/' | sed 's/,"ttl.*$//'
}

# Функция удаления выбранной DNS-записи из данных временного хранения
# и подготовки данных для загрузки на GoDaddy
prepare_zone(){
   sed "s/$(delete_str)/deleted/" ${TMP_DIR}/${TMP_FILE}.$(dns_domains) | sed '/deleted/ d' | sed ':a; /$/N; s/\n//; ta' | /bin/sed 's/"/\"/g' | /bin/sed 's/{/\{/g' | /bin/sed 's/}/\}/g'
}

### MODE interactive #################################################################

echo " "
echo "!!!ATTENTION!!! Данная программа предназначена ТОЛЬКО для УДАЛЕНИЯ DNS-записей"
echo "типов A, CNAME, NS, MX из файла описания DNS-zone средствами API GoDaddy"
echo "Если вы не знаете о чём идёт речь лучше откажитесь от использования данной программы"
echo " "
echo "Для продолжения введите \"yes\" или \"no\" для выхода из программы"
echo -n '(yes|no): '
read ANSWER
case ${ANSWER} in
  [yY]|[yY][eE][sS])
    echo "Он сказал - \"Поехали!\""
    echo "..."
    echo " "
  ;;
  *)
    echo "Goodbye!"
    exit 1
esac

# Выбор DNS-домена
echo "Для продолжения выберите номер строки с именем требуемого dns-домена"
while [ 1 ]
 do
    select ONEDOMAIN in $(get_domains) quit
      do
        # Если выбрано quit значит выход из программы
        if [ ${ONEDOMAIN} = quit ]; then
          echo "Goodbye!"
          exit 1
        fi
      
        # В остальных случаях используем выбранный вариант и выходим из цикла
        dns_domains(){
          echo ${ONEDOMAIN}
        }

        break
      done

    # Проверяем правильность выбора
    if [ ! $(dns_domains) ]
      then
        echo "Выберите один из предложенных вариантов!"
      else
        break
    fi
  done

echo " "
echo "Вы выбрали DNS-домен $(dns_domains)"
echo "..."
echo " "

### Select procedure #################################################################

# Создадим резервную копию для выбранного домена
echo "Создадим резервную копию для выбранного домена"

if [ ! `ls ./ | grep gobackup.sh` ]
  then
      GOBACKUPPATH=`find / -name "gobackup.sh" 2>/dev/null | grep -m 1 '/godaddy/'`
  else
      GOBACKUPPATH='./gobackup.sh'
fi

${GOBACKUPPATH} $(dns_domains)

# Создадим временный файл для хранения текущего состояния DNS-zone
golist > ${TMP_DIR}/${TMP_FILE}.$(dns_domains)

# Проверим, что локальная копия файла описания DNS-zone была создана
if [ ! -f ${TMP_DIR}/${TMP_FILE}.$(dns_domains) ]; then
  echo "!!! ATTENTION !!!"
  echo "Локальная копия файла DNS-zone для домена $(dns_domains) не была создана!!!"
  exit 1
fi

# Выбираем данные для удаления
echo " "
echo "Выберите из списка DNS-запись, предназначенную для удаления, указав номер строки:"
echo " "

while [ 1 ]
  do
    select DELETESTR in $(select_str) quit
      do
        # Если выбрано quit значит выход из программы
        if [ ${DELETESTR} = quit ]; then
          echo "Goodbye!"
          rm ${TMP_DIR}/${TMP_FILE}.$(dns_domains)*
          exit 1
        fi
      
        # В остальных случаях используем выбранный вариант и выходим из цикла
        delete_str(){
          echo ${DELETESTR}
        }

        break
      done

    # Проверяем правильность выбора
    if [ ! $(delete_str) ]
      then
        echo " "
        echo "Выберите один из предложенных вариантов!"
      else
        break
    fi
  done

echo " "
echo "Вы выбрали для удаления следующую DNS-запись:"
echo "$(delete_str)"
echo " "
echo "Для продолжения введите \"yes\" или \"no\" для выхода из программы"
echo -n '(yes|no): '
read ANSWERNEW
case ${ANSWERNEW} in
  [yY]|[yY][eE][sS])
    echo "Он сказал - \"Поехали!\""
    echo "..."
    echo " "
  ;;
  *)
    echo "Goodbye!"
    exit 1
esac

### Delete procedure #################################################################

# Выполняем процедуру загрузки файла описания dns-zone с учётом внесённых изменений
# на сервер GoDaddy

echo "Start delete DNS-records procedure for $(dns_domains)"

curl -s -X PUT -H "${AUTH}" -H "Content-Type: application/json" --data $(prepare_zone) https://api.godaddy.com/v1/domains/$(dns_domains)/records | sed 's/{//' | sed 's/}//' &> ${TMP_DIR}/${TMP_FILE}.$(dns_domains).out

# Проверяем результат выполнения команды перезаливки файла описания DNS-zone.
# В некоторых случаях из-за формата TXT-записей загрузка данных не происходит
# из-за неверноего форматирования данных внутри самого скрипта.
# Решить эту проблему на смог. По этой причине если загрузка данных на сервер
# GoDaddy не прошла успешно, то формируется команда, которую достаточно просто
# скопировать в командную строку и выполнить вручную. В этом случае команда
# проходит успешно.
if [ -s ${TMP_DIR}/${TMP_FILE}.$(dns_domains).out ]
  then
    echo "... "
    echo "Упс! Что-то пошло не так..."
    echo "Указанная DNS-запись не была удалена."
    echo "Если вы всё же хотите завершить процедуру удаления выбранной DNS-записи"
    echo "Вам неоходимо выполнить в ручную в консоли приведённую ниже команду:"
    echo " "
    
    HEADERS=`echo "-H \"${AUTH}\" -H \"Content-Type: application/json\" --data '"`
    URLPATH=`echo "' https://api.godaddy.com/v1/domains/$(dns_domains)/records"`
    prepare_zone_for_manual(){
      sed "s/$(delete_str)/deleted/" ${TMP_DIR}/${TMP_FILE}.$(dns_domains) | sed '/deleted/ d' | sed ':a; /$/N; s/\n//; ta'
    }
    echo "curl -s -X PUT ${HEADERS}$(prepare_zone_for_manual)${URLPATH}"
    echo " "
  else
    echo "{}"
    echo "Goodbye!"
fi

# Удаляем временные файлы
rm ${TMP_DIR}/${TMP_FILE}.$(dns_domains)*

exit 0
