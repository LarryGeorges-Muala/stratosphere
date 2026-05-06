from django.shortcuts import render, get_object_or_404
from django.http import HttpResponse, Http404, HttpResponseRedirect, JsonResponse
from django.template import loader
from django.db.models import F
from django.urls import reverse
from django.views import generic
from django.views.decorators.csrf import csrf_exempt, csrf_protect, ensure_csrf_cookie
from django.views.decorators.http import require_http_methods
from django.middleware.csrf import get_token, _check_token_format

from . import _helpers_modules, models

import json

# Create your views here.

@require_http_methods(['GET'])
def health(request):
    return JsonResponse(_helpers_modules.health())


@require_http_methods(['POST'])
@csrf_protect
def index(request):
    return JsonResponse(
        _helpers_modules.create_booking(
            request.body,
            'json'
        )
    )


@require_http_methods(['POST'])
@csrf_protect
def create_user_session(request):
    return JsonResponse(
        _helpers_modules.create_user_session(
            request.body,
            'json'
        )
    )


@require_http_methods(['POST'])
@csrf_protect
def clear_user_session(request):
    return JsonResponse(
        _helpers_modules.delete_user_session(
            request.body,
            'json'
        )
    )


@require_http_methods(['POST'])
@csrf_exempt
@ensure_csrf_cookie
def fetch_user_session(request):
    user_session = _helpers_modules.fetch_user_session(
        request.body,
        'json'
    )
    return JsonResponse(user_session)
