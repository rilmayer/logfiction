RSpec.describe Logfiction do
  before do
    @la = Logfiction::AccessLog.new()
  end

  it "has a version number" do
    expect(Logfiction::VERSION).not_to be nil
  end

  it "generate_user" do
    users = @la.generate_users(n_users=100, users=[])
    expect(users.size).to eq 100
  end

  it "generate_items" do
    items = @la.generate_items(n_users=100, users=[])
    expect(items.size).to eq 100
  end

  it "get_next_items" do
    from_state_id = 1
    to_state_id = 2
    current_items = ["a", "b", "c"]
    @la.generate_state_transiton()
    next_items = @la.get_next_items(from_state_id, to_state_id, current_items)
    expect(next_items.size).to be > 0
  end
end
