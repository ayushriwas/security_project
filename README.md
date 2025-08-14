# security_project

The terraform files are for only creating the vpc networks infrastructure which contains the two security groups, one security group has the permissions for ssh access etc...
These files do not have any involvement in the project I just configured terraform for the purpose of creating the vpc  network which helped me to save charges of aws vpc.

so you can ignore them.

# AWS Threat Detection and Prevention Project

## Overview

The AWS Security Project is designed to protect cloud workloads through a layered, automated, and adaptable approach. It leverages AWS-native services and traditional firewall strategies to provide real-time threat detection and automated remediation.

Key AWS services used:

* **Amazon GuardDuty** – Continuous threat detection
* **AWS Lambda** – Automated response workflows
* **Amazon EventBridge** – Event-driven triggers
* **Amazon SNS** – Alert distribution
* **Amazon CloudWatch** – Centralized logging

## Architecture Models

### Hybrid Cloud Architecture

* pfSense deployed in VPC as a DMZ.
* Full control over firewall rules.
* pfSense logs → Sysloger EC2 instance → Amazon CloudWatch.
* EventBridge detects patterns → triggers SNS alerts & Lambda for permanent IP block.

Flow:

1. Attacker hits pfSense (DMZ).
2. pfSense blocks IP temporarily, logs event.
3. Logs forwarded to CloudWatch.
4. EventBridge matches pattern → SNS alert + Lambda block.

### All-AWS Architecture

* pfSense deployed entirely within AWS in public subnet DMZ.
* Simplified integration with AWS services.
* Same detection and automation as Hybrid Cloud but fully cloud-native.

## Phased Threat Detection

### Phase 1 – Perimeter Defense (pfSense Layer)

* Detects & blocks traffic before reaching internal resources.
* Logs sent via Sysloger → CloudWatch.
* EventBridge triggers SNS alert + Lambda permanent block.

### Phase 2 – Internal Defense (GuardDuty Layer)

* GuardDuty monitors VPC if pfSense is bypassed.
* Detects suspicious actions like port scans, brute-force, unauthorized access.
* EventBridge triggers SNS alert + Lambda isolation.

## Security Benefits

* Multi-layer detection.
* Automated mitigation.
* Centralized monitoring.
* Works in hybrid or AWS-only environments.
* Maintains audit-ready logs.

## Services Used

* Amazon VPC
* EC2 (Attacker, pfSense, Sysloger, Webserver)
* Amazon CloudWatch
* Amazon EventBridge
* Amazon SNS
* AWS Lambda
* Amazon GuardDuty
* IAM Roles & Policies

## Usage

1. Deploy VPC & EC2 instances.
2. Configure pfSense firewall rules & logging.
3. Set up Sysloger with CloudWatch Agent.
4. Configure EventBridge rules.
5. Deploy Lambda functions for IP isolation.
6. Subscribe to SNS alerts.
