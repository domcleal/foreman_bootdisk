module ForemanBootdisk::Orchestration
  module Compute
    extend ActiveSupport::Concern

    included do
      after_validation :queue_bootdisk_compute
      before_destroy :queue_bootdisk_compute_destroy
    end

    def queue_bootdisk_compute
      return unless compute? && errors.empty? && new_record?
      return unless compute_resource.kind_of? Foreman::Model::Libvirt
      queue.create(:name   => _("Configure boot disk for %s") % self, :priority => 5,
                   :action => [self, :setComputeBootdisk])
    end

    def setComputeBootdisk
      vm ||= compute_resource.find_vm_by_uuid(uuid)

      logger.info "Generating boot disk"
      tmpl = self.bootdisk_template_render
      ForemanBootdisk::ISOGenerator.generate(:ipxe => tmpl) do |image|
        image_file = File.new(image)
        logger.info "Uploading boot disk to compute resource %s" % compute_resource
        client = compute_resource.send(:client)

        vol = client.volumes.new(:name => "#{vm.name}-bootdisk", :capacity => "#{image_file.size}b")
        vol.save

        libvirt_vol = client.send(:get_volume, {:key => vol.path}, true)
        libvirt_vol.upload(image_file, 0, image_file.size)
      end
    end
  end
end
