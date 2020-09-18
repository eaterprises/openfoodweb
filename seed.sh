#!/bin/bash

echo '-------------------------------------------------------'
echo 'BEGIN: docker-compose run web bundle exec rake db:reset'
echo '-------------------------------------------------------'
docker-compose run web bundle exec rake db:reset
echo '-----------------------------------------------------'
echo 'END: docker-compose run web bundle exec rake db:reset'
echo '-----------------------------------------------------'

echo '--------------------------------------------------------------'
echo 'BEGIN: docker-compose run web bundle exec rake db:test:prepare'
echo '--------------------------------------------------------------'
docker-compose run web bundle exec rake db:test:prepare
echo '------------------------------------------------------------'
echo 'END: docker-compose run web bundle exec rake db:test:prepare'
echo '------------------------------------------------------------'

echo '--------------------------------------------------------------'
echo 'BEGIN: docker-compose run web bundle exec rake ofn:sample_data'
echo '--------------------------------------------------------------'
docker-compose run web bundle exec rake ofn:sample_data
echo '------------------------------------------------------------'
echo 'END: docker-compose run web bundle exec rake ofn:sample_data'
echo '------------------------------------------------------------'
