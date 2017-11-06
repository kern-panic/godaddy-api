#!/bin/bash
#
# Данная программа предназанчена для восстановления файла описания DNS-zone
# из файла резервной копии в формате API GoDaddy.
# Для запуска программы в интерактивном режиме необходимо запустить её без аргументов
# командной строки.
# Для запуска программы в "ручном" режиме необходимо указать в качестве аргумента
# имя файла резервной копии включая абсолютный путь к нему.
# Например,
# /srv/backup/godaddy/mlm-soft.cloud/mlm-soft.cloud_2017-10-19_0625
#

### SET VARIABLES ####################################################################

# Секретная пара для аутентификации на GoDaddy
source /path/to/.env
AUTH="Authorization: sso-key ${KEY}:${SECRET}"

# Зададим значение переменной "FIND" по умолчанию. Данная переменная управляет
# поведением программы в случае, если указанное в командной строке имя dns-домена
# не соответствует ни одному активному dns-домену в учётной записи GoDaddy
FIND=none

# Установка места хранения резервных копий
BACKUP_DIR="/var/backups/godaddy"

# Установим директорию и файл для временного хранения данных DNS-zone
TMP_DIR='/tmp'
TMP_FILE='godaddy.tmp.file'

### SET FUNCTIONS ####################################################################

# Функция для динамического получения списка dns-доменов, имеющих статус "ACTIVE"
get_domains(){
  curl -s -X GET -H "${AUTH}" https://api.godaddy.com/v1/domains/ | sed 's/}/}\n/g' | sed 's/^,//' | grep -i active | cut -f 2 -d , | cut -f 2 -d : | sed 's/"//g'
}

# Функция для получения имени домена из имени файла резервной копии DNS-zone
get_domain_from_file(){
  echo ${PATHFILE} | cut -f 5 -d '/'
}

# Функция получения списка файлов резервных копий
get_path_file(){
  ls ${BACKUP_DIR}/$(dns_domains)/
}

# Функция для подготовки данных из файла резервной копии
prepare_zone(){
  sed ':a; /$/N; s/\n//; ta' $(backup_file) | sed 's/"/\"/g' | sed 's/{/\{/g' | sed 's/}/\}/g'
}

### SELECT MODE ###################################################################### 

# Определяем режим работы программы в зависимости от наличия или отсутствия аргументов
if [ ! $1 ]
  then
    MODE=interactive
  else
    MODE=manual
    # Проверяем существование заданного в командной строке файла
    if [ -f $1 ]
      then
        # Зададим путь к файлу резервной копии DNS-zone
        PATHFILE=$1
        backup_file(){
          echo ${PATHFILE}
        }
      else
        echo "Указанный файл не существует"
        echo "Запустите программу без аргументов для перехода в интерактивный режим"
        exit 1
    fi
fi

### MODE manual ######################################################################

if [ ${MODE} = manual ]; then
  for SEARCH in $(get_domains)
    do
      FIND=false
      if [ $(get_domain_from_file) = ${SEARCH} ]; then
        dns_domains(){
          echo ${SEARCH}
        }
        FIND=true 
        break
      fi
    done
fi

# Если FIND=false значит указанный аргумент командной строки
# не соответствует ни одному активному dns-домену
if [ ${FIND} != none ]; then
  if [ ${FIND} = false ]; then
    echo "Вы задали имя файла, не соответствующее ни одному активному dns-домену"
    echo "Запустите программу без аргументов для перехода в интерактивный режим"
    exit 1
  fi
fi

### MODE interactive #################################################################

if [ ${MODE} = interactive ]; then
  echo " "
  echo "Вы запустили программу для восстановления файла описания dns-zone" 
  echo "из файла резервной копии для активных dns-доменов через API GoDaddy."
  echo " "

  # Выбираем DNS-домен из тех, которые имеют статус "ACTIVE" для учётной записи GoDaddy
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
          echo " "
          echo "Выберите один из предложенных вариантов!"
        else
          break
      fi
    done

  # Выбираем один из сохранённых файлов резервных копий
  echo " "
  echo "Для продолжения выберите номер строки с именем файла описания DNS-zone,"
  echo "соответствующий требуемой дате создания резервной копии"

  while [ 1 ]
    do
      select FILENAME in $(get_path_file) quit
        do
          # Если выбрано quit значит выход из программы
          if [ ${FILENAME} = quit ]; then
            echo "Goodbye!"
            exit 1
          fi
      
          # В остальных случаях используем выбранный вариант и выходим из цикла
          backup_file(){
            echo ${BACKUP_DIR}/$(dns_domains)/${FILENAME}
          }

          break
        done

      # Проверяем правильность выбора
      if [ ! $(backup_file) ]
        then
          echo " "
          echo "Выберите один из предложенных вариантов!"
        else
          break
      fi
    done
fi

### Restore procedure ################################################################

# Выполняем процедуру восстановления файла описания dns-zone

echo " "
echo "Start restore procedure for $(dns_domains)"

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
      sed ':a; /$/N; s/\n//; ta' $(backup_file)
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
