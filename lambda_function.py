import json
import boto3
import re

def lambda_handler(event, context):
    print("Received event: " + json.dumps(event))

    # Try to detect if this is a GuardDuty finding or a pfSense syslog
    if 'detail' in event and 'type' in event['detail']:
        # -----------------
        # GuardDuty Handling
        # -----------------
        finding = event['detail']
        quarantine_sg_name = 'quarantine-sg'

        if 'EC2' in finding['type']:
            try:
                instance_id = finding['resource']['instanceDetails']['instanceId']
                region = finding['region']
                vpc_id = finding['resource']['instanceDetails']['networkInterfaces'][0]['vpcId']

                ec2 = boto3.client('ec2', region_name=region)

                response = ec2.describe_security_groups(
                    Filters=[
                        {'Name': 'group-name', 'Values': [quarantine_sg_name]},
                        {'Name': 'vpc-id', 'Values': [vpc_id]},
                    ]
                )

                if not response['SecurityGroups']:
                    print(f"Error: Quarantine security group '{quarantine_sg_name}' not found in VPC '{vpc_id}'.")
                    return

                quarantine_sg_id = response['SecurityGroups'][0]['GroupId']
                print(f"Found quarantine security group ID: {quarantine_sg_id}")
                print(f"Isolating instance {instance_id} by changing its security group to {quarantine_sg_id}")

                ec2.modify_instance_attribute(
                    InstanceId=instance_id,
                    Groups=[quarantine_sg_id]
                )

                print(f"Successfully isolated instance {instance_id} by moving it to security group {quarantine_sg_id}.")

            except Exception as e:
                print(f"Error isolating instance: {e}")
                raise e

    elif 'awslogs' in event.get('awslogs', {}):
        # -----------------
        # pfSense Syslog Handling
        # -----------------
        import base64, gzip
        payload = base64.b64decode(event['awslogs']['data'])
        log_data = json.loads(gzip.decompress(payload))
        print("Decoded CloudWatch log data:", json.dumps(log_data, indent=2))

        quarantine_sg_name = 'quarantine-sg'
        region = 'ap-south-1'  # <-- change to your AWS region
        ec2 = boto3.client('ec2', region_name=region)

        # Extract all attacker IPs from the log events
        for log_event in log_data['logEvents']:
            message = log_event['message']
            ip_match = re.findall(r'\b(?:[0-9]{1,3}\.){3}[0-9]{1,3}\b', message)

            if ip_match:
                attacker_ip = ip_match[0]
                print(f"Detected attacker IP from pfSense logs: {attacker_ip}")

                try:
                    # Find the instance with this IP in the VPC
                    ec2_instances = ec2.describe_instances(
                        Filters=[{'Name': 'private-ip-address', 'Values': [attacker_ip]}]
                    )

                    for reservation in ec2_instances['Reservations']:
                        for instance in reservation['Instances']:
                            instance_id = instance['InstanceId']
                            vpc_id = instance['VpcId']

                            response = ec2.describe_security_groups(
                                Filters=[
                                    {'Name': 'group-name', 'Values': [quarantine_sg_name]},
                                    {'Name': 'vpc-id', 'Values': [vpc_id]},
                                ]
                            )

                            if not response['SecurityGroups']:
                                print(f"Error: Quarantine SG '{quarantine_sg_name}' not found in VPC '{vpc_id}'.")
                                continue

                            quarantine_sg_id = response['SecurityGroups'][0]['GroupId']
                            print(f"Found quarantine SG ID: {quarantine_sg_id}")
                            print(f"Isolating instance {instance_id} by changing its SG to {quarantine_sg_id}")

                            ec2.modify_instance_attribute(
                                InstanceId=instance_id,
                                Groups=[quarantine_sg_id]
                            )

                            print(f"Successfully isolated {instance_id} due to pfSense log detection.")

                except Exception as e:
                    print(f"Error isolating attacker from pfSense logs: {e}")
