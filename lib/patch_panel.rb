# Software patch-panel.
class PatchPanel < Trema::Controller
  def start(_args)
    @patch = Hash.new { [] }
		@mirror = Hash.new { [] }
    logger.info 'PatchPanel started.'
  end

  def switch_ready(dpid)
    @patch[dpid].each do |port_a, port_b|
      delete_flow_entries dpid, port_a, port_b
      add_flow_entries dpid, port_a, port_b
    end
  end

  def create_patch(dpid, port_a, port_b)
    add_flow_entries dpid, port_a, port_b
    @patch[dpid] += [[port_a, port_b].sor]
  end

  def delete_patch(dpid, port_a, port_b)
    delete_flow_entries dpid, port_a, port_b
    @patch[dpid] -= [[port_a, port_b].sort]
  end

  def create_mirror(dpid, port_monitor, port_mirror)
		add_mirror_entries dpid, port_monitor, port_mirror
		@mirror[dpid] += [[port_monitor, port_mirror]]
  end

	def delete_mirror(dpid, port_monitor, port_mirror)
		if @mirror[dpid].include?([port_monitor, port_mirror]) then
			delete_mirror_entry dpid, port_monitor, port_mirror
			@mirror[dpid] -= [[port_monitor, port_mirror]]
		end
	end

  private

  def add_flow_entries(dpid, port_a, port_b)
    send_flow_mod_add(dpid,
                      match: Match.new(in_port: port_a),
                      actions: SendOutPort.new(port_b))
    send_flow_mod_add(dpid,
                      match: Match.new(in_port: port_b),
                      actions: SendOutPort.new(port_a))
  end

	def add_mirror_entries(dpid, port_monitor, port_mirror)
		send_flow_mod_delete(dpid, match: Match.new(in_port: port_mirror))
		for patch_tmp in @patch[dpid].each do
			port_in = patch_tmp[0]
			port_out = patch_tmp[1]
			if port_in == port_monitor then
				send_flow_mod_delete(dpid, match: Match.new(in_port: port_in))
				send_flow_mod_add(dpid, 
											match: Match.new(in_port: port_monitor),
											actions: [
												SendOutPort.new(port_out),
												SendOutPort.new(port_mirror)
											])
			end		
		end
	end

  def delete_flow_entries(dpid, port_a, port_b)
    send_flow_mod_delete(dpid, match: Match.new(in_port: port_a))
    send_flow_mod_delete(dpid, match: Match.new(in_port: port_b))
  end

	def delete_mirror_entry(dpid, port_monitor, port_mirror)
		send_flow_mod_delete(dpid, match: Match.new(in_port: port_monitor))
		for patch_tmp in @patch[dpid].each do
			port_in = patch_tmp[0]
			port_out = patch_tmp[1]
			if port_in == port_monitor then
				send_flow_mod_add(dpid,
											match: Match.new(in_port: port_in),
											actions: SendOutPort.new(port_out))
			end
		end
	end

	def dump(dpid)
    str = "Patches:\n"
    for patch in @patches[dpid].each do
      port_in = patch[0]
      port_out = patch[1]
      str += "\t"
      str += port_in.to_s
      str += "<->"
      str += port_out.to_s
      str += "\n"
    end
    
		str += "Mirrors:\n"
    for mirror in @mirrors[dpid].each do
      port_monitor = mirror[0]
      port_mirror = mirror[1]
      str += "\t"
      str += port_monitor.to_s
      str += "->"
      str += port_mirror.to_s
      str += "\n"
    end
    str
  end

end
