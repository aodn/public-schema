"""
Helper functions for validating schemas and resources using the Frictionless framework
"""

from pathlib import Path
from typing import Union

from frictionless import Resource, validate, FrictionlessException
from frictionless.schemes.remote import RemoteControl


def validate_resource(resouce: Union[str, Path, Resource], http_timeout: int = 100):
    """
    Validate the given resource (including data accessed from the specified path)

    :param resouce: frictionless.Resource object, or path to a resource file
    :param http_timeout: http response timeout in seconds
    :return: tuple (valid:bool, errors:list)
    """
    if not isinstance(resouce, Resource):
        resouce = Path(resouce)
        if not resouce.exists():
            raise FileNotFoundError(f"Resource file {resouce.resolve()} does not exist")

    try:
        # create (a copy of) Resource object
        # set longer timeout to allow for slow response
        res = Resource(resouce, control=RemoteControl(http_timeout=http_timeout))
    except FrictionlessException as e:
        return False, [f"Not a valid resource description:\n{e}"]

    try:
        report = validate(res)
    except FrictionlessException as e:
        return False, [f"An exception occurred during validation:\n{e}"]

    return report.valid, report.flatten(['name', 'message'])
