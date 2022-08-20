# WSGI module for use with Apache mod_wsgi or gunicorn

from opentelemetry.instrumentation.wsgi import OpenTelemetryMiddleware
from opentelemetry.sdk.trace.sampling import TraceIdRatioBased
from opentelemetry.sdk.trace.export import (
    SimpleSpanProcessor
)
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import (
    OTLPSpanExporter,
)
from opentelemetry import trace

from mapproxy.wsgiapp import make_wsgi_app
import os

# # uncomment the following lines for logging
# create a log.ini with `mapproxy-util create -t log-ini`
from logging.config import fileConfig
import os.path

fileConfig(r'/mapproxy/log.ini', {'here': os.path.dirname(__file__)})

# create map proxy application
map_proxy = make_wsgi_app(r'/mapproxy/mapproxy.yaml', reloader=True)

application = map_proxy

# Get telemetry endpoint from env
endpoint = os.environ.get('TELEMETRY_ENDPOINT', 'localhost:4317')
tracing_enabled = os.environ.get('TELEMETRY_TRACING_ENABLED', 'false')
sampling_ratio_denominator = int(os.environ.get(
    'TELEMETRY_SAMPLING_RATIO_DENOMINATOR', '1000'))

if tracing_enabled.strip().lower() == 'true':
    # Create span exporter
    span_exporter = OTLPSpanExporter(
        endpoint=endpoint,
    )

    # sample 1 in every n traces
    sampler = TraceIdRatioBased(1 / sampling_ratio_denominator)

    # Set trance provider and processor
    tracer_provider = TracerProvider(sampler=sampler)
    trace.set_tracer_provider(tracer_provider)
    processor = SimpleSpanProcessor(span_exporter)
    tracer_provider.add_span_processor(processor)

    # Add OpenTelemetry middleware and activate application
    application = OpenTelemetryMiddleware(
        application, None, None, tracer_provider)
