#!/bin/bash

##################################
##################################
# Author: Vitor Alves
# Date: 2021-12-03
# Version: 1.0

# Describe of script
# - [X] Check status for RDS and EC2 instances
# - [X] Start and Stop instances
# - [ ] Log all actions
# - [ ] Changing CloudFlare A records
# - [ ] Sending email with complete actions

##################################

# Variables
AWS_REGION=us-east-1
AWS_RDS_CLUSTER_NAME="your RDS Cluster names"
AWS_EC2_INSTANCES_IDS="your ec2 instances ids"
AWS_EC2_PUBLIC_IP=""
AWS_EC2_NAME=""
AWS_RUNTIME_PERIOD=
AWS_RDS_RUNNING=0
AWS_EC2_RUNNING=0
LOG_PATH=
LOG_FILE=
EXEC_TIMEOUT=10

##################################
##################################
#Functions

function dateNow() {
    date "+%FT%T"
}

function getEC2Name(){
    AWS_EC2_NAME=$(aws ec2 describe-instances --region $AWS_REGION --instance-ids $1 --query 'Reservations[0].Instances[0].Tags[0].Value' --o text)
}

function getEC2PublicIP(){
    AWS_EC2_PUBLIC_IP=$(aws ec2 describe-instances --region $AWS_REGION  --instance-ids $1 --query 'Reservations[0].Instances[0].NetworkInterfaces[0].[Association.PublicIp]' --o text)
}

function checkStatusRDS(){
    STATUS=$(aws rds describe-db-clusters --region $AWS_REGION --db-cluster-identifier $1 --query 'DBClusters[0].Status')
    if [[ "$STATUS" = *"available"* ]]; then
        AWS_RDS_RUNNING=1
        echo "[$(dateNow)] The instance ${1} is running."
    else
        AWS_RDS_RUNNING=0
        echo "[$(dateNow)] The instance ${1} is not running."
    fi
}

function checkStatusEC2(){
    STATUS=$(aws ec2 describe-instances --region $AWS_REGION --instance-ids $1 --query 'Reservations[0].Instances[0].[State.Name]' --o text)
    getEC2Name $1
    if [[ "$STATUS" = *"running"* ]]; then
        AWS_EC2_RUNNING=1
        echo "[$(dateNow)] The instance ${1} with name ${AWS_EC2_NAME} is running."
    else
        AWS_EC2_RUNNING=0
        echo "[$(dateNow)] The instance ${1} with name ${AWS_EC2_NAME} is not running."
    fi
}

function statusEnvironment(){
    for DB_CLUSTER in $AWS_RDS_CLUSTER_NAME;
        do
            checkStatusRDS $DB_CLUSTER
        done
        for EC2_INSTANCE_ID in $AWS_EC2_INSTANCES_IDS;
        do
            checkStatusEC2 $EC2_INSTANCE_ID
        done
}

function getAllEC2PublicIP(){
    for EC2_INSTANCE_ID in $AWS_EC2_INSTANCES_IDS;
    do
      getEC2PublicIP $EC2_INSTANCE_ID
      getEC2Name $EC2_INSTANCE_ID
      echo "[$(dateNow)] The Public IP for instance ${AWS_EC2_NAME} is ${AWS_EC2_PUBLIC_IP}"
    done
}

function startRDS(){
    for DB_CLUSTER in $AWS_RDS_CLUSTER_NAME;
        do
            # Check Status RDS
            checkStatusRDS $DB_CLUSTER
            if [ $AWS_RDS_RUNNING = 0 ];
            then
                echo "[$(dateNow)] Starting instance ${DB_CLUSTER} now."
                aws rds start-db-cluster --db-cluster-identifier $DB_CLUSTER
                while [ $AWS_RDS_RUNNING = 0 ] ;
                do
                    checkStatusRDS $DB_CLUSTER
                    sleep $EXEC_TIMEOUT
                done
                echo "[$(dateNow)] The instance ${DB_CLUSTER} is started."
            fi
    done
}

function stopRDS(){
    for DB_CLUSTER in $AWS_RDS_CLUSTER_NAME;
        do
            # Check Status RDS
            checkStatusRDS $DB_CLUSTER
            if [ $AWS_RDS_RUNNING = 1 ];
            then
                echo "[$(dateNow)] Stopping instance ${DB_CLUSTER} now."
                aws rds stop-db-cluster --db-cluster-identifier $DB_CLUSTER
                while [ $AWS_RDS_RUNNING = 1 ] ;
                do
                    checkStatusRDS $DB_CLUSTER
                    sleep $EXEC_TIMEOUT
                done
                echo "[$(dateNow)] The instance ${DB_CLUSTER} is stopped."
            fi
    done
}


function startEC2(){
    for EC2_INSTANCE_ID in $AWS_EC2_INSTANCES_IDS;
        do
            # Check EC2 Status
            checkStatusEC2 $EC2_INSTANCE_ID
            if [ $AWS_EC2_RUNNING = 0 ];
            then
                echo "[$(dateNow)] Starting instance ${EC2_INSTANCE_ID} now."
                aws ec2 start-instances --region $AWS_REGION --instance-ids $EC2_INSTANCE_ID
                while [ $AWS_EC2_RUNNING = 0 ] ;
                do
                    checkStatusEC2 $EC2_INSTANCE_ID
                    sleep $EXEC_TIMEOUT
                done
                echo "[$(dateNow)] The instance ${EC2_INSTANCE_ID} is started."
            fi
    done
}

function stopEC2(){
    for EC2_INSTANCE_ID in $AWS_EC2_INSTANCES_IDS;
        do
            # Check Status RDS
            checkStatusEC2 $EC2_INSTANCE_ID
            if [ $AWS_EC2_RUNNING = 1 ] ;
            then
                echo "[$(dateNow)] Stopping instance ${EC2_INSTANCE_ID}."
                aws ec2 stop-instances --region $AWS_REGION --instance-ids $EC2_INSTANCE_ID
                while [ $AWS_EC2_RUNNING = 1 ] ;
                do
                    checkStatusEC2 $EC2_INSTANCE_ID
                    sleep $EXEC_TIMEOUT
                done
                echo "[$(dateNow)] The instance ${EC2_INSTANCE_ID} is stopped."
            fi
    done
}

##################################
##################################
# Execution

case $1 in
    startEC2 ) startEC2 ;;
    stopEC2  ) stopEC2 ;;
    startRDS ) startRDS ;;
    stopRDS  ) stopRDS;;
    status   ) statusEnvironment;;
    ec2-ips  ) getAllEC2PublicIP;;
    stopAll  ) stopEC2
               stopRDS
               ;;
    starAll  ) startRDS
               startEC2
               ;;
    *        ) echo "Incorrect value. Please use these parameters lists: startEC2 | stopEC2 | startRDS | stopRDS | status | ec2-ips | startAll | stopAll";;
esac