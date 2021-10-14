#! /usr/bin/env python3

"""
Helper functions for validating schemas and resources using the Frictionless framework
"""


import sys

from frictionless import Resource, Layout, validate, FrictionlessException
from yaml import YAMLError
from yaml.scanner import ScannerError


def resource_valid(resouce:[str, Resource]):
    """
    Validate the given resource (including data accessed from the specified path)

    :param resouce: frictionless.Resource object, path to a resource file
    :return: tuple (valid:bool, errors:list)
    """
    if not isinstance(resouce, Resource):
        try:
            resource = Resource(resouce)
        except FrictionlessException as e:
            return False, [f"Not a valid resource description:\n{e}"]

    resource.layout = Layout(skip_fields=['FID'])

    try:
        report = validate(resource)
    except FrictionlessException as e:
        return False, [f"An exception occurred during validation:\n{e}"]

    return report.valid, report.flatten(['name', 'message'])


if __name__ == '__main__':
    if len(sys.argv) < 2:
        print('Usage: {} resource.yaml ...'.format(*sys.argv))

    nfail = 0
    for res in sys.argv[1:]:
        print('\nValidating {} ... '.format(res), end='')
        valid, errors = resource_valid(res)
        if valid:
            print('Valid')
        else:
            print('Not valid!')
            nfail += 1
            print(*errors[:5], sep='\n')
            if len(errors) > 5:
                print('... ({} errors)'.format(len(errors)))

    exit(nfail)
