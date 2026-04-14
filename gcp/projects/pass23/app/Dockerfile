FROM mcr.microsoft.com/dotnet/sdk:7.0 AS build
WORKDIR /source
COPY ./ContosoUniversity /source
RUN dotnet publish -r linux-musl-x64 --self-contained true -c Release -o /deploy

FROM mcr.microsoft.com/dotnet/runtime-deps:7.0-alpine-amd64 AS runtime

# Fix for openssl CVE-2023-5363
# Add i18n support
RUN echo 'http://dl-cdn.alpinelinux.org/alpine/v3.14/main' >> /etc/apk/repositories && \
    apk update --no-cache && \
    apk add --no-cache openssl && \
    apk add --no-cache icu

WORKDIR /app
COPY --from=build /deploy .

# Default port for Cloud Run
ENV ASPNETCORE_URLS="http://0.0.0.0:8080"

ENTRYPOINT ["/app/ContosoUniversity"]
