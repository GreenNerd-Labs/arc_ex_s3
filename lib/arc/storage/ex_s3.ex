defmodule Arc.Storage.ExS3 do
  @default_expire_time 60*5

  alias Arc.Storage.S3

  alias ExAws.Auth.Credentials
  alias ExAws.Auth.Utils
  alias ExAws.Auth.Signatures

  defdelegate put(definition, version, file_and_scope), to: S3
  defdelegate url(definition, version, file_and_scope, options), to: S3
  defdelegate delete(definition, version, file_and_scope), to: S3

  def presigned_put_url(definition, file_and_scope) do
    s3_bucket = definition.storage_bucket()
    s3_key = definition.storage_key(nil, file_and_scope)

    {:ok, url} = ExAws.S3.presigned_url(config(), :put, s3_bucket, s3_key, expires_in: @default_expire_time)
    url
  end

  def head(%{bucket: bucket, key: key}) do
    result =
      bucket
      |> ExAws.S3.head_object(key)
      |> ExAws.request()

    case result do
      {:ok, _} -> true
      _ -> false
    end
  end

  #
  # Post Object
  #

  def post_object_auth_data(%{} = raw_data, policy) do
    config = config()
    datetime = :calendar.universal_time

    %{
      "x-amz-algorithm": "AWS4-HMAC-SHA256",
      "x-amz-credential": Credentials.generate_credential_v4(:s3, config, datetime),
      "x-amz-date": Utils.amz_date(datetime),
      "x-amz-signature": Signatures.generate_signature_v4("s3", config, datetime, policy)
    }
    |> Map.merge(raw_data)
  end

  def post_object_url(%{bucket: bucket}) do
    config = config()

    port = case config.port do
      binport when is_binary(binport) -> String.to_integer(binport)
      port -> port
    end

    %URI{
      scheme: "http",
      host: config.host,
      port: config.port,
      path: Path.join("/", bucket)
    }
    |> URI.to_string()
  end

  #
  # Helpers
  #

  defp config do
    ExAws.Config.new(:s3, Application.get_all_env(:ex_aws))
  end
end
