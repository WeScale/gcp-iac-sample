#!/usr/bin/env python

import yaml
from functions_iac import delete_kubernetes, delete_data, delete_base, delete_tfstate, delete_bastion, delete_fw
import sys

if len(sys.argv) > 1:
    name_file = sys.argv[1]
    print("delete from file: ../plateform/manifests/"+name_file+".yaml")
else:
    name_file = raw_input("Nom du fichier: ")

try:
    from yaml import CLoader as Loader, CDumper as Dumper
except ImportError:
    from yaml import Loader, Dumper

with open("../plateform/manifests/"+name_file+".yaml", 'r') as stream:
    try:
        plateform=yaml.load(stream, Loader=Loader)
        print(plateform)

        print("Delete plateform with name: " + plateform['name'])

        if "gke" in plateform['infrastructure']:
            print("Layer-kubernetes...")
            delete_kubernetes(plateform)


        if "bastion" in plateform['infrastructure']:
            print("Layer-bastion...")
            delete_bastion(plateform)

        if 'cloudsql' in plateform['infrastructure']:
            print("Layer-data...")
            unique_id = 'test'
            if 'instance-num' in plateform['infrastructure']['cloudsql']:
                unique_id = plateform['infrastructure']['cloudsql']['instance-num']
                del plateform['infrastructure']['cloudsql']['instance-num']

            user1_password="test"
            user2_password="test"
            delete_data(plateform, user1_password, user2_password, unique_id)

            with open("../plateform/manifests/"+name_file+".yaml", 'w') as yaml_file:
                yaml.dump(plateform, yaml_file, default_flow_style=False)

        print("Delete fw...")
        delete_fw(plateform['name'])

        print("Layer-base...")
        delete_base(plateform)

        print("Delete tfstate...")
        delete_tfstate(plateform['name'])
        
    except yaml.YAMLError as exc:
        print(exc)
    except Exception as inst:
        print(inst)
