#! /usr/bin/env python3

"""
Helper functions for validating schemas and resources using the Frictionless framework
"""


import sys

from frictionless import Resource, Layout, validate_resource


def validate_resource_from_geoserver(resouce:[str, Resource]):
    """
    Validate the given resource, accessing the data from

    :param resouce: frictionless.Resource object, path to a resource file
    :return: frictionless.Report object
    """
    if not isinstance(resouce, Resource):
        resource = Resource(resouce)

    resource.layout = Layout(skip_fields=['FID'])

    return validate_resource(resource)


if __name__ == '__main__':
    if len(sys.argv) < 2:
        print('Usage: {} resource.yaml ...'.format(*sys.argv))

    nfail = 0
    for res in sys.argv[1:]:
        print('Validating {} ... '.format(res), end='')
        report = validate_resource_from_geoserver(res)
        if report.valid:
            print('Valid')
        else:
            print('Not valid!')
            nfail += 1
            errors = report.flatten(['name', 'message'])
            print(*errors[:5], sep='\n')
            if len(errors) > 5:
                print('... ({} errors)'.format(len(errors)))

    exit(nfail)
