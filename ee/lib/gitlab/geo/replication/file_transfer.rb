# frozen_string_literal: true

module Gitlab
  module Geo
    module Replication
      # This class is responsible for:
      #   * Requesting an Upload file from the primary
      #   * Saving it in the right place on successful download
      #   * Returning a detailed Result object
      class FileTransfer < BaseTransfer
        def initialize(file_type, upload)
          if upload.local?
            super(local_file_attributes(file_type, upload))
          else
            super(remote_file_attributes(file_type, upload))
          end

        rescue ObjectStorage::RemoteStoreError
          ::Gitlab::Geo::Logger.warn "Error trying to transfer a remote object as a local object."
        end

        private

        def local_file_attributes(file_type, upload)
          {
            file_type: file_type,
            file_id: upload.id,
            filename: upload.absolute_path,
            uploader: upload.build_uploader,
            expected_checksum: upload.checksum,
            request_data: build_request_data(file_type, upload)
          }
        end

        def remote_file_attributes(file_type, upload)
          {
            file_type: file_type,
            file_id: upload.id,
            uploader: upload.build_uploader,
            request_data: build_request_data(file_type, upload)
          }
        end

        def build_request_data(file_type, upload)
          {
            id: upload.model_id,
            type: upload.model_type,
            checksum: upload.checksum,
            file_type: file_type,
            file_id: upload.id
          }
        end
      end
    end
  end
end
