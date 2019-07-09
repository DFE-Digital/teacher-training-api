require 'spec_helper'
require 'mcb_helper'

describe 'mcb az apps psql' do
  it 'runs psql for localhost' do
    allow(MCB).to receive(:exec_command).with(
      "psql",
      "-h", "localhost",
      "-U", "manage_courses_backend",
      "-d", "manage_courses_backend_development"
    )

    with_stubbed_stdout do
      $mcb.run(%w[az apps psql])
    end
  end

  it 'runs psql for azure server' do
    app_config = {
      'MANAGE_COURSES_POSTGRESQL_SERVICE_HOST' => 'azhost',
      'PG_DATABASE'                            => 'pgdb',
      'PG_USERNAME'                            => 'azuser',
      'PG_PASSWORD'                            => 'azpass',
      'RAILS_ENV'                              => 'qa',
    }
    allow(MCB::Azure).to(receive(:get_config).and_return(app_config))

    allow(MCB).to receive(:exec_command).with(
      "psql",
      "-h", "azhost",
      "-U", "azuser",
      "-d", "pgdb"
    )

    with_stubbed_stdout(stdin: "qa") do
      $mcb.run(%w[az apps psql -E qa])
    end
  end
end
