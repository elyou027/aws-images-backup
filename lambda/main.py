#!/usr/bin/env python3
# -*- coding: utf-8 -*-
import sys
import boto3
import os
import re
from dateutil.parser import parse
import datetime
import time

#os.environ["AWS_PROFILE"] = 'vlad'
ec2 = boto3.client('ec2')
client = boto3.resource('ec2')


def days_old(date):
    get_date_obj = parse(date)
    date_obj = get_date_obj.replace(tzinfo=None)
    diff = datetime.datetime.now() - date_obj
    return diff.days


def snapshots_cleanup(image_id):
    my_snapshots = client.snapshots.filter(Filters=[{'Name': 'tag:ImageID', 'Values': [image_id]}])

    for s in my_snapshots:
        print(f"Removing snapshot: {s.id} that was created by AMI id: {image_id}")
        s.delete(DryRun=False)


def images_cleanup(plan_name):
    images_list = []
    images = client.images.filter(Filters=[
        {'Name': 'tag-key', 'Values': ["BackupSaveDays"]},
        {'Name': 'tag:BackupPolicy', 'Values': [plan_name]}
        ])
    for i in images:
        save_days = 0
        for days in [element.get('Value') for element in i.tags if
                     element.get('Key', "none") == "BackupSaveDays"]:
            save_days = int(days)
        images_list.append({'id': i.id, 'creation_data': i.creation_date, 'save_days': save_days})

    ims = sorted(images_list, key=lambda k: k['creation_data'])[:-1]

    del_num = 0
    for i in ims:
        for image in images:
            if image.id == i['id']:
                if days_old(image.creation_date) > i['save_days']:
                    print(f"Deregistering image: {image.name} {image.creation_date} {image.image_id}")
                    image.deregister(DryRun=False)
                    snapshots_cleanup(i['id'])
                    del_num += 1
                else:
                    print(f"Image is {image.name} {image.creation_date} {image.image_id} is younger "
                          f"then {i['save_days']} "
                          f"days. So it is not ready to be deleted")
    if del_num == 0:
        print("Have not found any images for deletion")
    return True


def create_image(instance_id, name, plan_name, save_days):
    stripped_name = name.replace(" ", "_")
    date_now = datetime.datetime.now().strftime("%Y_%m_%d_%H_%M_%S")
    result = ec2.create_image(
        NoReboot=True,
        Name=f"{stripped_name.upper()}-{date_now}-{plan_name}",
        Description=f'Backup of {name}. Backup policy is: {plan_name}',
        InstanceId=instance_id
    )

    print(f"Created backup for instance with ID: {instance_id} ({name}). Resuling Image ID is: {result['ImageId']}. "
          f"Result status is: {result['ResponseMetadata']['HTTPStatusCode']}")
    time.sleep(5.2)
    image = ec2.describe_images(ImageIds=[result['ImageId']])['Images'][0]
    resources = [result['ImageId']]
    for device in image['BlockDeviceMappings']:
        if 'SnapshotId' in device['Ebs'].keys():
            resources.append(device['Ebs']['SnapshotId'])

    if len(resources) > 0:
        print(f"Added tags for resource IDs: {resources}")
        response = ec2.create_tags(
            Resources=resources,
            Tags=[
                {
                    'Key': 'BackupPolicy',
                    'Value': plan_name
                },
                {
                    'Key': 'InstanceID',
                    'Value': instance_id
                },
                {
                    'Key': 'ImageID',
                    'Value': result['ImageId']
                },
                {
                    'Key': 'BackupSaveDays',
                    'Value': str(save_days)
                },
                {
                    'Key': 'Name',
                    'Value': f"{stripped_name.upper()}-{date_now}-{plan_name}"
                }
            ]
        )


def images_handler(event, context):
    plan_name = event.get("plan_name", "BackupDaily")
    print(f"Starting backup for policy name: {plan_name}")
    filters = [{'Name': 'tag-key', 'Values': [plan_name]}]
    response = ec2.describe_instances(Filters=filters)
    if len(response) == 0:
        print(f"Have not found any Instances for the BackupPolicy: {plan_name}")
        sys.exit(1)
    for reservation in response.get("Reservations", []):
        for instance in reservation.get("Instances", []):
            instance_id = instance['InstanceId']
            save_days = 0
            name_tag = "undefined_name"
            for days in [element.get('Value') for element in instance["Tags"] if element.get('Key', "none") == plan_name]:
                save_days = int(days)
            for name in [element.get('Value') for element in instance["Tags"] if element.get('Key', "none") == "Name"]:
                name_tag = name
            if save_days > 0:
                create_image(
                    instance_id=instance_id,
                    name=name_tag,
                    plan_name=plan_name,
                    save_days=save_days
                )

    images_cleanup(plan_name)
    return True
