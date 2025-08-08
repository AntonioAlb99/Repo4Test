variable "number_of_vms" {
  type        = number
  default     = 1
  description = "Numărul de VM-uri"
}

variable "tags" {
  type = map(string)
  default = {
    proiect     = "NotepadPP"
    mediu       = "Dev"
    departament = "IT"
  }
}
