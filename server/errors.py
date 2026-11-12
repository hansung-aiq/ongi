"""공통 오류 처리.

모든 오류를 과제서 형식으로 돌려준다.
    {"error": "E-409", "message": "이 상황에는 이미 메시지가 있어요"}
"""
import logging

from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.openapi.utils import get_openapi
from fastapi.responses import JSONResponse
from starlette.exceptions import HTTPException as StarletteHTTPException

log = logging.getLogger("ongi")

# 오류 코드 → HTTP 상태 코드
STATUS = {"E-400": 400, "E-404": 404, "E-409": 409, "E-413": 413, "E-500": 500}


class ApiError(Exception):
    """API 코드에서 raise ApiError("E-404", "가족을 찾을 수 없어요") 처럼 쓴다."""

    def __init__(self, code: str, message: str):
        self.code = code
        self.message = message


def error_response(code: str, message: str) -> JSONResponse:
    return JSONResponse(status_code=STATUS[code], content={"error": code, "message": message})


def register(app: FastAPI) -> None:
    @app.exception_handler(ApiError)
    async def handle_api_error(request: Request, exc: ApiError):
        return error_response(exc.code, exc.message)

    # 필수 값 누락, 타입 틀림 등 요청 형식 오류 → E-400
    @app.exception_handler(RequestValidationError)
    async def handle_validation(request: Request, exc: RequestValidationError):
        first = exc.errors()[0]
        field = ".".join(str(p) for p in first["loc"] if p != "body")
        if first["type"] == "extra_forbidden":
            return error_response("E-400", f"보낼 수 없는 값이에요: {field}")
        return error_response("E-400", f"요청 값이 올바르지 않아요: {field} ({first['msg']})")

    # 없는 주소(404), 허용되지 않는 메서드(405) 등 FastAPI가 직접 내는 오류
    @app.exception_handler(StarletteHTTPException)
    async def handle_http(request: Request, exc: StarletteHTTPException):
        if exc.status_code == 404:
            return error_response("E-404", "요청한 주소를 찾을 수 없어요")
        if exc.status_code == 405:
            return error_response("E-400", "이 주소에서 허용되지 않는 요청 방식이에요")
        return error_response("E-400", str(exc.detail))

    # 그 밖의 예상 못 한 오류 → E-500. 원인은 서버 터미널 로그에 남긴다.
    @app.exception_handler(Exception)
    async def handle_unexpected(request: Request, exc: Exception):
        log.exception("처리되지 않은 오류: %s %s", request.method, request.url.path)
        return error_response("E-500", "서버에서 오류가 났어요")

    # /docs 화면에도 실제와 같게 보이도록, FastAPI가 자동으로 적는 422를 400 오류 모양으로 바꾼다.
    def openapi():
        if app.openapi_schema:
            return app.openapi_schema
        schema = get_openapi(title=app.title, version=app.version, routes=app.routes)
        schemas = schema.setdefault("components", {}).setdefault("schemas", {})
        schemas.pop("HTTPValidationError", None)
        schemas.pop("ValidationError", None)
        schemas["Error"] = {
            "type": "object",
            "properties": {"error": {"type": "string"}, "message": {"type": "string"}},
        }
        for path in schema["paths"].values():
            for op in path.values():
                responses = op.get("responses", {})
                if responses.pop("422", None) is not None:
                    responses["400"] = {
                        "description": "Bad Request",
                        "content": {"application/json": {"schema": {"$ref": "#/components/schemas/Error"}}},
                    }
        app.openapi_schema = schema
        return schema

    app.openapi = openapi
