#!/bin/bash
#
# Данная программа предназначена для создания резервных копий файлов описания dns-zone
# для доменов, управляемых через аккаунт на сервисе GoDaddy.
# Для запуска программы в интерактивном режиме необходимо запустить её без аргументов
# командной строки.
# Для запуска программы в "ручном" режиме необходимо указать в качестве аргумента
# значение "all" для создания резервных копий всех dns-доменов в статусе "ACTIVE".
# Или указать в качестве аргумента командной строки имя конкретного dns-домена.
#

### SET VARIABLES ####################################################################

# Секретная пара для аутентификации на GoDaddy
source ./.env
AUTH="Authorization: sso-key ${KEY}:${SECRET}"

# Установка временных меток
DATE=`date +%Y-%m-%d_%H%M`

# Установка места хранения резервных копий
BACKUP_DIR="/var/backups/godaddy"

# Зададим значение переменной "COMPARE" по умолчанию. Данная переменная управляет
# включением процедуры проверки указанного в командной строке имени dns-домена
COMPARE=no

# Зададим значение переменной "FIND" по умолчанию. Данная переменная управляет
# поведением программы в случае, если указанное в командной строке имя dns-домена
# не соответствует ни одному активному dns-домену в учётной записи GoDaddy
FIND=none

### SET FUNCTIONS ####################################################################

# Функция для динамического получения списка dns-доменов, имеющих статус "ACTIVE"
get_domains(){
  curl -s -X GET -H "${AUTH}" https://api.godaddy.com/v1/domains/ | sed 's/}/}\n/g' | sed 's/^,//' | grep -i active | cut -f 2 -d , | cut -f 2 -d : | sed 's/"//g'
}

# Проверим существование директорий для хранения резервных копий файлов dns-zone.
# И создадим их в случае отсутствия
for DIRECTORY in $(get_domains)
  do
    [ -d ${BACKUP_DIR}/${DIRECTORY} ] || mkdir -p ${BACKUP_DIR}/${DIRECTORY}
  done

# Функция создания резервных копий файлов описания dns-zone
backup_domains(){
  curl -s -X GET -H "${AUTH}" https://api.godaddy.com/v1/domains/$1/records | sed 's/}/}\n/g' > ${BACKUP_DIR}/$1/$1_${DATE}
}

### SELECT MODE ######################################################################

# Определяем режим работы программы в зависимости от наличия или отсутствия аргументов
if [ ! $1 ]
  then
    MODE=interactive
  else
    MODE=manual
fi

### MODE manual ######################################################################

if [ ${MODE} = manual ]; then
  if [ $1 = all ]
    then
      # Если в качестве аргумента указано значение "all",
      # тогда выполняем резервное копирование для всех активных доменов.
      dns_domains(){
        get_domains
      }
    else
      # Иначе задаём переменную COMPARE для включения сравнения
      # аргумента с активными dns-доменами (защита "от дурака")
      COMPARE=yes
  fi
fi

# Если COMPARE=yes выполняем проверку
if [ ${COMPARE} = yes ]; then
  for SEARCH in $(get_domains)
    do
      FIND=false
      if [ $1 = ${SEARCH} ]; then
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
    echo "Вы ввели не правильное dns-имя домена"
    echo "Запустите программу без аргументов для перехода в интерактивный режим"
    exit 1
  fi
fi


### MODE interactive #################################################################

if [ ${MODE} = interactive ]; then
  echo "Вы запустили программу для создания резервных копий активных dns-доменов,"
  echo "через API GoDaddy"
  echo "Для продолжения выберите номер строки с именем требуемого dns-домена"
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
fi


### BackUp procedure #################################################################

# Выполняем процедуру резервного копирования

echo "Start backup procedure"

for DNSDOMAINS in $(dns_domains)
  do
    backup_domains ${DNSDOMAINS}

    # Оставляем в папке с резервными копиями только за последние 14 дней
    find ${BACKUP_DIR}/${DNSDOMAINS} -type f -mtime +14 -delete
    
    echo "Finishing backup for ${DNSDOMAINS} dns-zone"
  done

echo ""
echo "AlRight!"

exit 0
