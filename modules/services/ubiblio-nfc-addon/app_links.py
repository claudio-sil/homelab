from fastapi import APIRouter
from fastapi.responses import JSONResponse


router = APIRouter()


@router.get(
    "/.well-known/assetlinks.json",
    include_in_schema=False,
)
def assetlinks():
    return JSONResponse(
        content=[
            {
                "relation": [
                    "delegate_permission/common.handle_all_urls"
                ],
                "target": {
                    "namespace": "android_app",
                    "package_name": "il.co.silberman.ubiblionfc",
                    "sha256_cert_fingerprints": [
                        "02:3A:62:FB:0B:CC:16:FB:C7:87:27:B2:4E:C7:1A:B1:D7:76:0B:4A:9F:CA:AF:D9:CD:02:DF:7C:9A:72:63:2C"
                    ],
                },
            }
        ]
    )
