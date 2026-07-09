# frozen_string_literal: true

# Code-quality guard. Prevents regressions of the forbidden patterns
# documented in TODO.work/02 and the global CLAUDE.md:
#
#   - .send(:private_method) — bypasses encapsulation
#   - instance_variable_set / instance_variable_get — same
#   - respond_to?(...) — duck-typing that hides type errors
#   - require_relative "..." — eager-loads, breaks load path
#   - require "cdd/..." — same
#
# The generated racc parser (lib/cdd/cddal/generated_parser.rb) is
# exempt because it is machine-generated from lib/cdd/cddal/cddal.y.
# Fix the grammar source and regenerate; do not hand-edit the parser.

RSpec.describe "code quality" do
  let(:library_sources) do
    Dir.glob("lib/**/*.rb").reject do |f|
      f.end_with?("/generated_parser.rb")
    end
  end

  def grep(pattern)
    library_sources.each_with_object([]) do |file, hits|
      File.readlines(file).each_with_index do |line, idx|
        hits << "#{file}:#{idx + 1}: #{line.strip}" if line.match?(pattern)
      end
    end
  end

  it "does not call .send on private methods" do
    # `.send(` is fine for public APIs and for test doubles; the
    # forbidden case is calling private/protected methods via send.
    # We approximate by flagging any `.send(:` whose argument starts
    # with an underscore (a Ruby convention for private).
    hits = grep(/\.send\(:?_\w/)
    expect(hits).to be_empty,
      "private-method .send found — see TODO.work/02:\n#{hits.join("\n")}"
  end

  it "does not use instance_variable_set / instance_variable_get" do
    hits = grep(/instance_variable_(set|get)\b/)
    expect(hits).to be_empty,
      "instance_variable_set/get found — breaks encapsulation:\n#{hits.join("\n")}"
  end

  it "does not use respond_to? for type checks" do
    hits = grep(/\.respond_to\?\(/)
    expect(hits).to be_empty,
      "respond_to? found — use is_a? or design the hierarchy (TODO.work/02):\n#{hits.join("\n")}"
  end

  it "does not use require_relative" do
    hits = grep(/^\s*require_relative\s/)
    expect(hits).to be_empty,
      "require_relative found — use autoload in the parent namespace (TODO.work/01):\n#{hits.join("\n")}"
  end

  it "does not use require for internal cdd paths" do
    hits = grep(/^\s*require\s+["']cdd\//)
    expect(hits).to be_empty,
      "internal require found — use autoload in the parent namespace (TODO.work/01):\n#{hits.join("\n")}"
  end
end
