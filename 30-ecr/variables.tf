variable "project" {
    default = "roboshop"
}

variable "environment" {
    default = "dev"
}

variable "images" {
    default = ["frontend", "catalogue", "cart", "payment", "shipping", "user"]
}