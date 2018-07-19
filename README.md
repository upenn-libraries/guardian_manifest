# README for `guardian_manifest`

This is a Ruby script to generate CSV manifests for use in the [guardian workflow](https://github.com/upenn-libraries/guardian/) for transferring archives to Glacier in batches.

## Requirements:

* Ruby 2.2.5 or higher
* A [YAML file](inventory.yml.example) populated with shared manifest data and a list of the directive names of each archive to be transferred to Glacier in this batch with guardian

## Usage

To generate a guardian-compliant CSV, issue the following command from the terminal:

```bash
ruby guardian_manifest.rb inventory.yml
```

Where `inventory.yml` is the path to the YAML file you are using to create this manifest.  

This will output a CSV manifest called `guardian_manifest.csv` in the directory where the command was run.  If you wish to override the default, you can provide a custom filename at which the manifest will be saved locally, as an optional third argument like so:

```bash
ruby guardian_manifest.rb inventory.yml output_file.csv
```

## Populating the YAML inventory

The YAML inventory used to populate the guardian manifest should be in the following format:

```YAML
source: x
workspace: x
compressed_destination: x
compressed_extension: x
vault: x
application: x
method: x
description_values:
  owner: x
  location: x
directive_names:
  - dir_name_1
  - dir_name_2
  - dir_name_3
```

The values should correspond to:

* `source` - The source on guardian for the content that will populate the archive
  * Valid term(s) for use with the Docker deployment:
    * `bulwark_gitannex_remote`

* `workspace` - The path on guardian where the archive will be pulled from the source and assembled into its compressed for
  * Valid term(s) for use with the Docker deployment:
    * `zip_workspace`

* `compressed_destination` - The path on guardian where the compressed archive will be staged for transfer to Glacier
  * Valid terms for use with the Docker deployment:
    * `zip_workspace`

* `compressed_extension` - The file extension of the compressed archive
    * Valid term(s) for use with the guardian codebase:
      * `zip`

* `vault` - The name of the [Glacier vault](https://docs.aws.amazon.com/amazonglacier/latest/dev/working-with-vaults.html) where the archive will be transferred

* `application` - The name of the application stewarding the source data for the archives in this batch

  * Supported application(s)
    * `bulwark`

* `method` - The retrieval method required by the application to pull source content to the workspace so that it can be compressed and transferred

  * Supported method(s)
    * `gitannex`

* `description_values` - The key/value store of data apart from the directive name to add to the JSON blob of metadata for each archive transferred to Glacier.  The values `owner` and `location` are prepopulated in the example above, and any other key/value pairings can be added to the description metadata in the same way to your YAML file.

* `directive_names` - A multi-valued list of the directive names of each object to have an archive generated and transferred to Glacier.  

## Contributing

Bug reports and pull requests are welcome on GitHub at [https://github.com/upenn-libraries/guardian_manifest](https://github.com/upenn-libraries/guardian_manifest).

## License

This code is available as open source under the terms of the [Apache 2.0 License](https://opensource.org/licenses/Apache-2.0).
