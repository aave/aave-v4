#!/bin/bash

for FILE in certora/conf/*.conf
do
    echo ${FILE}
    certoraRun ${FILE} --compilation_steps_only
done
