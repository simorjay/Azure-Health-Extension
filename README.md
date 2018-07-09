---
title: HIPAA/HITRUST Health Data and AI - Extension 
description: Guidance for deploying the on premise host, and PAW for the Health Data & AI Blueprint
author: Simorjay 
ms.date: 06/27/2018
---

# Azure HIPAA/HITRUST Health Data and AI - Extension (PREVIEW)

## Overview

### Health Blueprint (add-on) to address SAW, and Azure Security ASC

The HIPAA/HITRUST Health Data and AI - Extension provides customers the ability to deploy the health blueprint to include a hybrid/x-premises deployment to understand how Azure Security Center and other 
security technologies such as end point host protection would work in the Healthcare solution.
This solution will help expose the effort to migration an on-premise SQL based solutions to Azure, and the need to use a Privileged Access Workstation (PAW) to securely manage all cloud based services and solutions.

![](images/design2.png)


### Deploying the solution overview

Step 1 Deploy a PAW solution to ensure that management of the services is done in a secure service model. 
This step is recommended to ensure that no access be done to subscription management without a isolated client host. 
Review [Privileged Access Workstation (PAW) for details.](https://docs.microsoft.com/en-us/windows-server/identity/securing-privileged-access/privileged-access-workstations)

Step 2 Deploy the [Azure Security and Compliance Data and AI Health Blueprint](https://docs.microsoft.com/en-us/azure/security/blueprints/azure-health)
Extention capabilities start at step 3

Step 3 Deploy the Health data and AI (Extension) – Deployment will stand up a Windows server (IaaS)              
             with a MSSQL server. A bacpac will load a sample 10,000 patient records. 

![](images/ra2.png)

Step 4 Run script to migrate data to Azure SQL db PaaS deployed in blueprint

Step 5 View revised data in PowerBi (PowerBI dashboard will be updated)
     (documentation for SQL firewall to only connect to SAW host)

Step 6 View ASC to see the solution security stance (update) 
		This requires enumeration of the security benefits accrued from using ASC
			What are the endpoints we’re monitoring?






# Azure Security and Compliance Blueprint - HIPAA/HITRUST Health Data and AI  


Health organizations all over the world are leveraging the power of AI and the cloud to improve outcomes and accelerate performance.  The blueprint provides a secure end-to-end foundation for organizations to ingest, store, analyze and interact with sensitive and regulated data. The blueprint provides a Implementation and automation to help deploy a Health Insurance Portability and Accountability Act (HIPAA) and Health Information Trust Alliance (HITRUST) ready environment.  The blueprint includes step-by-step documentation, cybersecurity threat model, component architecture, customer responsibility matrix, external audit report and deployment scripts to automate cloud deployment.

**[Solution Overview](https://)** 
\(Redirect to docs.microsoft.com/azure/security/\)

[![](./images/deploy.png)](./deployment.md)

**[FAQ](./faq.md)** 

**[Threat model](https://aka.ms/healththreatmodelext)**

**[Customer Responsibility Matrix](https://aka.ms/healthcrmblueprintext)**




# Disclaimer


 The deployment script is designed to deploy the core elements of the Azure Security and Compliance Blueprint - HIPAA/HITRUST Health Data and AI. The details of the solutions operation, and elements can be reviewed at aka.ms/healthcareblueprint
Copyright (c) Microsoft Corporation, and KenSci - All rights reserved.
Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is  furnished to do so, subject to the following conditions:
The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,  FITNESS FOR A PARTICULAR PURPOSE AND ONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.




