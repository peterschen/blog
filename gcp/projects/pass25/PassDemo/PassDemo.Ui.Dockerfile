# Stage 1: Build the application using the .NET SDK
FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build-env
WORKDIR /app

ENV HTTP_PORTS=5001

# # Copy project files and restore dependencies first
# # This leverages Docker layer caching. The restore step will only re-run if the .csproj file changes.
COPY PassDemo.Ui/PassDemo.Ui.csproj ./PassDemo.Ui/
COPY PassDemo.Common/PassDemo.Common.csproj ./PassDemo.Common/
RUN dotnet restore PassDemo.Ui/PassDemo.Ui.csproj

# Copy the rest of the application source code
COPY PassDemo.Ui ./PassDemo.Ui
COPY PassDemo.Common ./PassDemo.Common

# Publish the application for release, with a defined output path
RUN dotnet publish PassDemo.Ui -c Release -o out

# Stage 2: Create the final, smaller runtime image
FROM mcr.microsoft.com/dotnet/aspnet:9.0
WORKDIR /app
COPY --from=build-env /app/out .

EXPOSE 5001

# Define the entry point for the container. This runs the application.
ENTRYPOINT ["dotnet", "PassDemo.Ui.dll"]