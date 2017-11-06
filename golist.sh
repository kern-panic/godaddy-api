#!/bin/bash
#
# Данная программа предназанчена для получения файла описания DNS-zone
# в формате API GoDaddy.
# Для запуска программы в интерактивном режиме необходимо запустить её без аргументов
# командной строки.
# Для запуска программы в "ручном" режиме необходимо указать в качестве аргумента
# имя DNS-домена.
#

### SET VARIABLES ####################################################################

# Секретная пара для аутентификации на GoDaddy
source ./.env
AUTH="Authorization: sso-key ${KEY}:${SECRET}"

# Зададим значение переменной "FIND" по умолчанию. Данная переменная управляет
# поведением программы в случае, если указанное в командной строке имя dns-домена
# не соответствует ни одному активному dns-домену в учётной записи GoDaddy
FIND=none

### SET FUNCTIONS ####################################################################

# Функция для динамического получения списка dns-доменов, имеющих статус "ACTIVE"
get_domains(){
  curl -s -X GET -H "${AUTH}" https://api.godaddy.com/v1/domains/ | sed 's/}/}\n/g' | sed 's/^,//' | grep -i active | cut -f 2 -d , | cut -f 2 -d : | sed 's/"//g'
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
  echo " "
  echo "Вы запустили программу для просмотра файла описания dns-zone активных dns-доменов,"
  echo "через API GoDaddy"
  echo " "
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
fi

### Listing procedure ################################################################

# Выполняем процедуру просмотра файла описания dns-zone

echo " "
echo "Вы выбрали DNS-домен $(dns_domains)"
echo " "

curl -s -X GET -H "${AUTH}" https://api.godaddy.com/v1/domains/$(dns_domains)/records | sed 's/}/}\n/g'

echo " "
echo "Goodbye!"

exit 0
